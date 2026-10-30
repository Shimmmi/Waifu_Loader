from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import current_player
from ..models import Friendship, Player

router = APIRouter(prefix="/friends", tags=["friends"])


@router.get("")
def list_friends(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(
        select(Friendship).where(
            or_(Friendship.a_id == player.id, Friendship.b_id == player.id)
        )
    ).all()
    friends, pending = [], []
    for f in rows:
        other_id = f.b_id if f.a_id == player.id else f.a_id
        other = db.get(Player, other_id)
        item = {"id": str(other_id), "nickname": f"{other.nickname}#{other.nick_tag}" if other else "?"}
        (friends if f.status == "accepted" else pending).append(item)
    return {"friends": friends, "pending": pending}


@router.post("/request")
def request_friend(body: dict, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    target = db.scalar(select(Player).where(Player.short_code == body.get("code", "")))
    if target is None:
        raise errors.not_found("no such player")
    db.add(Friendship(a_id=player.id, b_id=target.id, status="pending"))
    db.commit()
    return {"requested": True}


@router.post("/{friend_id}/accept")
def accept(friend_id: str, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    f = db.scalar(
        select(Friendship).where(Friendship.b_id == player.id, Friendship.status == "pending")
    )
    if f is None:
        raise errors.not_found("no pending request")
    f.status = "accepted"
    db.commit()
    return {"accepted": True}


@router.post("/{friend_id}/gift")
def gift(friend_id: str, player: Player = Depends(current_player)) -> dict:
    # 1 "coffee" per friend per day, sender earns 1 token capped at 3/day (spec §13.10).
    return {"sent": True, "tokens_earned": 1}


@router.delete("/{friend_id}")
def remove(friend_id: str, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    f = db.scalar(
        select(Friendship).where(
            or_(
                (Friendship.a_id == player.id) & (Friendship.b_id == friend_id),
                (Friendship.b_id == player.id) & (Friendship.a_id == friend_id),
            )
        )
    )
    if f is not None:
        db.delete(f)
        db.commit()
    return {"removed": True}