from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import current_player
from ..models import Player, PvpMatch, PvpProfile
from ..schemas import PvpAttackRequest, PvpDefenseRequest
from ..security import server_time
from ..validator import duel

router = APIRouter(prefix="/pvp", tags=["pvp"])

LEAGUES = [(1700, "diamond"), (1500, "platinum"), (1300, "gold"), (1100, "silver"), (0, "bronze")]


def _league(rating: int) -> str:
    for floor, name in LEAGUES:
        if rating >= floor:
            return name
    return "bronze"


def _profile(db: Session, player: Player) -> PvpProfile:
    prof = db.get(PvpProfile, player.id)
    if prof is None:
        prof = PvpProfile(player_id=player.id)
        db.add(prof)
        db.flush()
    return prof


@router.get("/me")
def me(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    prof = _profile(db, player)
    db.commit()
    return {
        "rating": prof.rating,
        "league": prof.league,
        "passes": prof.passes,
        "wins": prof.wins,
        "losses": prof.losses,
        "defense": prof.defense,
        "defense_tactic": prof.defense_tactic,
    }


@router.put("/defense")
def put_defense(req: PvpDefenseRequest, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    prof = _profile(db, player)
    prof.defense = req.defense
    prof.defense_tactic = req.tactic
    prof.defense_locked_until = server_time() + 3600  # 1 h freeze (spec §13.6)
    db.commit()
    return {"ok": True, "locked_until": prof.defense_locked_until}


@router.post("/opponents")
def opponents(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    prof = _profile(db, player)
    db.commit()
    # Bots are mixed in for a small audience (spec §13.6).
    return {"opponents": [
        {"id": "bot_1", "nickname": "Манекен (тренировка)", "rating": prof.rating, "is_bot": True, "brigade": []},
    ]}


@router.post("/attack")
def attack(req: PvpAttackRequest, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    prof = _profile(db, player)
    if prof.passes <= 0:
        prof.passes = 0
        db.commit()
        return {"error": {"code": "no_passes", "message": "no passes left"}}
    prof.passes -= 1
    result = duel({"opponent_id": req.opponent_id, "tactic": req.tactic})
    if result is None:
        db.commit()
        # Validator degraded: duels rejected (spec §14.6).
        return {"error": {"code": "validator_unavailable", "message": "try later"}}
    outcome = result.get("result", "draw")
    if outcome == "win":
        prof.wins += 1
    elif outcome == "loss":
        prof.losses += 1
    db.add(PvpMatch(
        attacker=player.id,
        defender=player.id,
        defender_is_bot=True,
        seed=int(result.get("seed", 0)),
        tactics={"attacker": req.tactic, "defender": "balance"},
        result=result,
    ))
    prof.league = _league(prof.rating)
    db.commit()
    return result


@router.get("/history")
def history(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(
        select(PvpMatch).where(PvpMatch.attacker == player.id).limit(20)
    ).all()
    return {"matches": [{"result": m.result, "created_at": int(m.created_at.timestamp()) if m.created_at else 0} for m in rows]}


@router.get("/ladder")
def ladder(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    rows = db.scalars(select(PvpProfile).order_by(PvpProfile.rating.desc()).limit(100)).all()
    return {"ladder": [{"player_id": str(r.player_id), "rating": r.rating, "league": r.league} for r in rows]}