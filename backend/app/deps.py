from fastapi import Depends, Header
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import errors
from .config import settings
from .db import get_db
from .models import Player
from .security import token_hash


def _version_tuple(v: str) -> tuple[int, ...]:
    try:
        return tuple(int(x) for x in v.split("."))
    except ValueError:
        return (0,)


def check_client_version(x_client_version: str | None = Header(default=None)) -> None:
    """Reject too-old clients with 426 (spec §14.3)."""
    if x_client_version is None:
        return
    if _version_tuple(x_client_version) < _version_tuple(settings.min_client_version):
        raise errors.upgrade_required(
            f"client {x_client_version} < min {settings.min_client_version}"
        )


def current_player(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> Player:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise errors.unauthorized()
    token = authorization.split(" ", 1)[1].strip()
    player = db.scalar(
        select(Player).where(
            Player.token_hash == token_hash(token),
            Player.deleted_at.is_(None),
        )
    )
    if player is None:
        raise errors.unauthorized()
    return player