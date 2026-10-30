from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import current_player
from ..models import Player, Profile
from ..schemas import ReportRequest

router = APIRouter(tags=["profile"])


@router.get("/profile/{code}")
def get_profile(code: str, db: Session = Depends(get_db)) -> dict:
    player = db.scalar(select(Player).where(Player.short_code == code))
    if player is None:
        raise errors.not_found("no such profile")
    prof = db.get(Profile, player.id)
    return {
        "code": player.short_code,
        "nickname": f"{player.nickname}#{player.nick_tag}",
        "title": prof.title if prof else "",
        "frame": prof.frame if prof else "",
        "avatar": prof.avatar if prof else "",
        "rank": prof.rank if prof else 1,
        "lifetime_log10": prof.lifetime_log10 if prof else 0.0,
        "reorg_count": prof.reorg_count if prof else 0,
        "respect_count": prof.respect_count if prof else 0,
        "terminal_snapshot": prof.terminal_snapshot if prof else {},
        "showcase": prof.showcase if prof else {},
    }


@router.put("/profile")
def put_profile(
    body: dict,
    player: Player = Depends(current_player),
    db: Session = Depends(get_db),
) -> dict:
    prof = db.get(Profile, player.id)
    if prof is None:
        prof = Profile(player_id=player.id)
        db.add(prof)
    for key in ("title", "frame", "avatar", "rank", "showcase", "terminal_snapshot"):
        if key in body:
            setattr(prof, key, body[key])
    db.commit()
    return {"ok": True}


@router.post("/profile/{code}/respect")
def respect(code: str, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    target = db.scalar(select(Player).where(Player.short_code == code))
    if target is None:
        raise errors.not_found("no such profile")
    prof = db.get(Profile, target.id)
    if prof is None:
        prof = Profile(player_id=target.id)
        db.add(prof)
    prof.respect_count += 1
    db.commit()
    return {"respect_count": prof.respect_count}