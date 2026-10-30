import base64

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..config import settings
from ..db import get_db
from ..deps import current_player
from ..models import Player, Save
from ..schemas import SaveGetResponse, SavePutRequest, SavePutResponse

router = APIRouter(prefix="/save", tags=["save"])


def _decode(save_b64: str) -> bytes:
    try:
        blob = base64.b64decode(save_b64, validate=True)
    except Exception:
        raise errors.ApiError(422, "bad_payload", "save_b64 is not valid base64")
    if len(blob) > settings.save_max_bytes:
        raise errors.ApiError(413, "too_large", "save exceeds limit")
    return blob


@router.get("", response_model=SaveGetResponse)
def get_save(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> SaveGetResponse:
    save = db.get(Save, player.id)
    if save is None:
        return SaveGetResponse(revision=0, save_b64="", meta={}, updated_at=0)
    return SaveGetResponse(
        revision=save.revision,
        save_b64=base64.b64encode(save.blob).decode(),
        meta=save.meta,
        updated_at=int(save.updated_at.timestamp()) if save.updated_at else 0,
    )


@router.put("", response_model=SavePutResponse)
def put_save(
    req: SavePutRequest,
    player: Player = Depends(current_player),
    db: Session = Depends(get_db),
) -> SavePutResponse:
    blob = _decode(req.save_b64)
    save = db.get(Save, player.id)
    meta = req.meta.model_dump()

    if save is None:
        save = Save(player_id=player.id, revision=1, blob=blob, meta=meta)
        db.add(save)
        db.commit()
        return SavePutResponse(revision=1)

    # Optimistic concurrency (spec §13.3).
    if req.base_revision != save.revision:
        raise errors.conflict(
            "save_conflict",
            "revision mismatch",
            {"revision": save.revision, "server_meta": save.meta},
        )
    save.revision += 1
    save.blob = blob
    save.meta = meta
    db.commit()
    return SavePutResponse(revision=save.revision)