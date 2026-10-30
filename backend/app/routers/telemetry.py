from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..deps import current_player
from ..models import GlobalContrib, GlobalGoal, Player, ProgressWindow
from ..schemas import TelemetryRequest, TelemetryResponse
from ..security import server_time
from ..validator import power_estimate

router = APIRouter(prefix="/telemetry", tags=["telemetry"])


def _goal(db: Session) -> GlobalGoal:
    goal = db.scalar(select(GlobalGoal).order_by(GlobalGoal.stage.desc()))
    if goal is None:
        goal = GlobalGoal(stage=1, progress=0.0, target=1.0e9)
        db.add(goal)
        db.flush()
    return goal


@router.post("/progress", response_model=TelemetryResponse)
def progress(
    req: TelemetryRequest,
    player: Player = Depends(current_player),
    db: Session = Depends(get_db),
) -> TelemetryResponse:
    accepted = True
    reason: str | None = None

    last_seq = db.scalar(
        select(func.max(ProgressWindow.seq)).where(ProgressWindow.player_id == player.id)
    )
    if last_seq is not None and req.seq <= last_seq:
        accepted, reason = False, "seq"

    window_s = req.window_end - req.window_start
    if accepted and (window_s <= 0 or window_s > settings.telemetry_max_window_s):
        accepted, reason = False, "window"

    if accepted and req.power_snapshot is not None:
        rate_cap = power_estimate(req.power_snapshot.model_dump())
        if rate_cap is not None:
            cap = rate_cap * (window_s / 60.0) * 1.25 + 50.0
            if req.delta_tonnes > cap:
                accepted, reason = False, "rate"
            elif req.best_tpm > rate_cap * 1.1:
                accepted, reason = False, "tpm"

    db.add(ProgressWindow(
        player_id=player.id,
        seq=req.seq,
        window_start=req.window_start,
        window_end=req.window_end,
        delta_tonnes=req.delta_tonnes,
        best_tpm=req.best_tpm,
        gold_count=req.gold_count,
        accepted=accepted,
        reason=reason,
    ))

    goal = _goal(db)
    if accepted:
        # Verified deltas feed the global elevator-goal build (spec §13.8).
        scaled = req.delta_tonnes * settings.global_scale
        contrib = db.get(GlobalContrib, {"stage": goal.stage, "player_id": player.id})
        if contrib is None:
            contrib = GlobalContrib(stage=goal.stage, player_id=player.id, amount=scaled)
            db.add(contrib)
        else:
            contrib.amount += scaled
        goal.progress += scaled

    db.commit()
    return TelemetryResponse(
        accepted=accepted,
        hold=not accepted,
        server_time=server_time(),
        global_status={"stage": goal.stage, "progress": goal.progress},
    )