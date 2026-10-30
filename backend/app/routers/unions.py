from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import current_player
from ..models import Player, Union, UnionBoardPost, UnionMember
from ..schemas import DonateRequest, UnionCreateRequest

router = APIRouter(prefix="/unions", tags=["unions"])

CREATE_COST = 50_000
MAX_MEMBERS = 30
UPGRADE_BASE = 50_000


@router.get("")
def list_unions(db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(select(Union).limit(100)).all()
    return {"unions": [{"id": str(u.id), "name": u.name, "emblem": u.emblem, "fund": u.fund} for u in rows]}


@router.post("")
def create_union(req: UnionCreateRequest, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    if not (3 <= len(req.name) <= 20):
        raise errors.ApiError(422, "bad_name", "name must be 3..20 chars")
    exists = db.scalar(select(Union).where(Union.name == req.name))
    if exists is not None:
        raise errors.conflict("name_taken", "union name already used")
    union = Union(name=req.name, emblem=req.emblem, description=req.description, join_mode=req.join_mode)
    db.add(union)
    db.flush()
    db.add(UnionMember(union_id=union.id, player_id=player.id, role="chairman"))
    db.commit()
    return {"id": str(union.id)}


@router.get("/{union_id}")
def get_union(union_id: str, db: Session = Depends(get_db)) -> dict:
    union = db.get(Union, union_id)
    if union is None:
        raise errors.not_found("no such union")
    members = db.scalars(select(UnionMember).where(UnionMember.union_id == union.id)).all()
    return {
        "id": str(union.id),
        "name": union.name,
        "emblem": union.emblem,
        "description": union.description,
        "join_mode": union.join_mode,
        "fund": union.fund,
        "upgrades": union.upgrades,
        "member_count": len(members),
    }


@router.post("/{union_id}/join")
def join(union_id: str, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    union = db.get(Union, union_id)
    if union is None:
        raise errors.not_found("no such union")
    count = db.scalar(select(func.count()).select_from(UnionMember).where(UnionMember.union_id == union.id))
    if int(count or 0) >= MAX_MEMBERS:
        raise errors.conflict("union_full", "union is full")
    db.add(UnionMember(union_id=union.id, player_id=player.id, role="member"))
    db.commit()
    return {"joined": True}


@router.post("/{union_id}/leave")
def leave(union_id: str, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    m = db.get(UnionMember, {"union_id": union_id, "player_id": player.id})
    if m is not None:
        db.delete(m)
        db.commit()
    return {"left": True}


@router.post("/{union_id}/donate")
def donate(union_id: str, req: DonateRequest, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    union = db.get(Union, union_id)
    if union is None:
        raise errors.not_found("no such union")
    union.fund += max(0, req.amount)
    db.commit()
    return {"fund": union.fund}


@router.post("/{union_id}/upgrade")
def upgrade(union_id: str, body: dict, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    union = db.get(Union, union_id)
    if union is None:
        raise errors.not_found("no such union")
    key = str(body.get("key", ""))
    level = int(union.upgrades.get(key, 0))
    cost = int(UPGRADE_BASE * (2.5 ** level))
    if union.fund < cost:
        raise errors.conflict("insufficient_fund", "union fund too low", {"cost": cost})
    union.fund -= cost
    union.upgrades[key] = level + 1
    db.commit()
    return {"upgrades": union.upgrades, "fund": union.fund}


@router.get("/{union_id}/board")
def get_board(union_id: str, db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(
        select(UnionBoardPost).where(UnionBoardPost.union_id == union_id)
        .order_by(UnionBoardPost.created_at.desc()).limit(50)
    ).all()
    return {"posts": [{"id": p.id, "phrase_id": p.phrase_id, "sticker_id": p.sticker_id} for p in rows]}


@router.post("/{union_id}/board")
def post_board(union_id: str, body: dict, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    db.add(UnionBoardPost(
        union_id=union_id,
        player_id=player.id,
        phrase_id=int(body.get("phrase_id", 0)),
        sticker_id=int(body.get("sticker_id", 0)),
    ))
    db.commit()
    return {"posted": True}


@router.post("/{union_id}/members/{pid}/role")
def set_role(union_id: str, pid: str, body: dict, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    m = db.get(UnionMember, {"union_id": union_id, "player_id": pid})
    if m is None:
        raise errors.not_found("no such member")
    m.role = str(body.get("role", "member"))
    db.commit()
    return {"role": m.role}


@router.post("/{union_id}/members/{pid}/kick")
def kick(union_id: str, pid: str, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    m = db.get(UnionMember, {"union_id": union_id, "player_id": pid})
    if m is not None:
        db.delete(m)
        db.commit()
    return {"kicked": True}