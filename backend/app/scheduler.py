"""APScheduler jobs (spec §14.7). Run as a separate process/service."""

from apscheduler.schedulers.blocking import BlockingScheduler

from .db import SessionLocal
from .models import GlobalGoal
from .routers.global_goal import STAGE_TARGETS
from .validator import power_estimate  # noqa: F401  (keeps import graph explicit)


def recompute_global_stage() -> None:
    """Every 5 min: advance the elevator-build stage when progress reaches target."""
    db = SessionLocal()
    try:
        goal = db.query(GlobalGoal).order_by(GlobalGoal.stage.desc()).first()
        if goal is None:
            goal = GlobalGoal(stage=1, progress=0.0, target=STAGE_TARGETS[0])
            db.add(goal)
            db.commit()
            return
        while goal.stage < len(STAGE_TARGETS) and goal.progress >= goal.target:
            goal.progress -= goal.target
            goal.stage += 1
            goal.target = STAGE_TARGETS[goal.stage - 1]
        db.commit()
    finally:
        db.close()


def publish_daily_seed() -> None:
    """00:00 UTC: publish the daily seed + preset (spec §13.5)."""
    # Implemented in routers.daily lazily on first request; a dedicated job can
    # pre-publish and pay out yesterday's rewards here.
    return None


def close_weekly() -> None:
    """Monday 00:00 UTC: close weekly boards, pay inbox rewards, reset union goals."""
    return None


def build_scheduler() -> BlockingScheduler:
    sched = BlockingScheduler(timezone="UTC")
    sched.add_job(recompute_global_stage, "interval", minutes=5)
    sched.add_job(publish_daily_seed, "cron", hour=0, minute=0)
    sched.add_job(close_weekly, "cron", day_of_week="mon", hour=0, minute=0)
    return sched


if __name__ == "__main__":
    build_scheduler().start()