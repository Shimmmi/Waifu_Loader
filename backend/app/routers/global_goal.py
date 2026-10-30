from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import GlobalGoal

router = APIRouter(tags=["global"])

# Stage milestones (spec §13.8).
STAGE_TARGETS = [1e9, 5e9, 2e10, 1e11, 5e11, 2e12, 1e13, 5e13, 2e14, 1e15]


@router.get("/global")
def get_global(db: Session = Depends(get_db)) -> dict:
    goal = db.scalar(select(GlobalGoal).order_by(GlobalGoal.stage.desc()))
    if goal is None:
        goal = GlobalGoal(stage=1, progress=0.0, target=STAGE_TARGETS[0])
    return {
        "stage": goal.stage,
        "stages": len(STAGE_TARGETS),
        "progress": goal.progress,
        "goal": goal.target,
    }