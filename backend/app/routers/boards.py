from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc, select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import current_player
from ..models import BoardEntry, Player
from ..security import server_time

router = APIRouter(prefix="/boards", tags=["boards"])

BOARDS = {
    "tonnes_weekly", "tonnes_alltime", "best_tpm_weekly", "gold_weekly",
    "reorg_alltime", "daily_shift", "tender_weekly", "pvp_rating",
    "union_weekly", "global_contrib",
}


@router.get("")
def list_boards() -> dict:
    return {"boards": sorted(BOARDS)}


@router.get("/{board_id}")
def board(
    board_id: str,
    scope: str = Query(default="global"),
    limit: int = Query(default=100, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
) -> dict:
    rows = db.execute(
        select(BoardEntry, Player)
        .join(Player, Player.id == BoardEntry.player_id)
        .where(BoardEntry.board_id == board_id)
        .order_by(desc(BoardEntry.score))
        .limit(limit)
        .offset(offset)
    ).all()
    entries = [
        {"rank": offset + i + 1, "nickname": p.nickname, "score": e.score}
        for i, (e, p) in enumerate(rows)
    ]
    return {"board_id": board_id, "scope": scope, "entries": entries, "updated_at": server_time()}


@router.get("/{board_id}/me")
def board_me(
    board_id: str,
    player: Player = Depends(current_player),
    db: Session = Depends(get_db),
) -> dict:
    mine = db.scalar(
        select(BoardEntry).where(
            BoardEntry.board_id == board_id, BoardEntry.player_id == player.id
        )
    )
    if mine is None:
        return {"rank": None, "score": 0.0, "neighbors": []}
    higher = db.scalar(
        select(func_count(db, board_id, mine.score))
    )
    return {"rank": (higher or 0) + 1, "score": mine.score, "neighbors": []}


def func_count(db: Session, board_id: str, score: float) -> int:
    from sqlalchemy import func

    return db.scalar(
        select(func.count()).select_from(BoardEntry).where(
            BoardEntry.board_id == board_id, BoardEntry.score > score
        )
    ) or 0