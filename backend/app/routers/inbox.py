from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import current_player
from ..models import InboxItem, Player
from ..schemas import ReportRequest

router = APIRouter(tags=["inbox", "moderation"])


@router.get("/inbox")
def get_inbox(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(
        select(InboxItem).where(
            InboxItem.player_id == player.id, InboxItem.claimed_at.is_(None)
        ).order_by(InboxItem.created_at.desc())
    ).all()
    return {"items": [
        {"id": str(i.id), "kind": i.kind, "payload": i.payload,
         "created_at": int(i.created_at.timestamp()) if i.created_at else 0}
        for i in rows
    ]}


@router.post("/inbox/{item_id}/claim")
def claim(item_id: str, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    item = db.get(InboxItem, item_id)
    if item is None or item.player_id != player.id:
        raise errors.not_found("no such inbox item")
    if item.claimed_at is not None:  # idempotent
        return {"claimed": True, "payload": item.payload}
    item.claimed_at = datetime.now(timezone.utc)
    db.commit()
    return {"claimed": True, "payload": item.payload}


@router.post("/report")
def report(req: ReportRequest, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    from ..models import Report

    db.add(Report(
        player_id=player.id,
        target_type=req.target_type,
        target_id=req.target_id,
        reason=req.reason,
    ))
    db.commit()
    return {"reported": True}