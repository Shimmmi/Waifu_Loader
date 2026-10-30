from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import current_player
from ..models import DailyRun, DailySeed, Player
from ..schemas import DailySubmitRequest
from ..validator import daily
from .. import errors

router = APIRouter(prefix="/daily", tags=["daily"])

MAX_ATTEMPTS = 3


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


@router.get("")
def get_daily(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    day = _today()
    seed = db.get(DailySeed, day)
    if seed is None:
        seed = DailySeed(day_key=day, seed=f"seed-{day}", preset={})
        db.add(seed)
        db.commit()
    used = db.scalar(
        select(func.count()).select_from(DailyRun).where(
            DailyRun.day_key == day, DailyRun.player_id == player.id
        )
    )
    return {
        "daily_seed": seed.seed,
        "preset": seed.preset,
        "attempts_left": max(0, MAX_ATTEMPTS - int(used or 0)),
    }


@router.post("/submit")
def submit(req: DailySubmitRequest, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    day = _today()
    used = db.scalar(
        select(func.count()).select_from(DailyRun).where(
            DailyRun.day_key == day, DailyRun.player_id == player.id
        )
    )
    if int(used or 0) >= MAX_ATTEMPTS:
        raise errors.rate_limited("no daily attempts left")

    result = daily(req.model_dump())
    valid = result is not None
    score = float(result.get("score", 0.0)) if result else 0.0
    db.add(DailyRun(
        day_key=day,
        player_id=player.id,
        plan=req.model_dump(),
        score=score,
        valid=valid,
    ))
    db.commit()
    # Client pre-result is shown immediately; the server result is authoritative.
    return {"provisional": score, "valid": valid, "result": result or {}}