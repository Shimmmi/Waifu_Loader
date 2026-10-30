from fastapi import APIRouter, Depends

from ..deps import current_player
from ..models import Player
from ..schemas import TenderSubmitRequest
from ..validator import tender

router = APIRouter(prefix="/tender", tags=["tender"])


@router.get("")
def get_tender(player: Player = Depends(current_player)) -> dict:
    return {"tender_id": "tender-weekly", "rule": "standard", "attempts_left": 3}


@router.post("/submit")
def submit(req: TenderSubmitRequest, player: Player = Depends(current_player)) -> dict:
    result = tender(req.model_dump())
    return {"valid": result is not None, "result": result or {}}