from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import errors
from ..db import get_db
from ..deps import current_player
from ..models import Player, Profile
from ..schemas import GuestRequest, GuestResponse, RecoverRequest, RenameRequest
from ..security import (
    code_hash,
    new_recovery_code,
    new_token,
    nick_tag,
    short_code,
    token_hash,
)

router = APIRouter(prefix="/auth", tags=["account"])

_BANNED = {"admin", "root", "moderator", "модератор"}


def _valid_nick(nick: str) -> bool:
    if not (3 <= len(nick) <= 16):
        return False
    if nick.lower() in _BANNED:
        return False
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_ ")
    allowed |= set("абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
    return all(ch in allowed for ch in nick)


@router.post("/guest", response_model=GuestResponse)
def guest(req: GuestRequest, db: Session = Depends(get_db)) -> GuestResponse:
    token = new_token()
    code = new_recovery_code()
    player = Player(
        short_code=short_code(),
        nickname="Грузчик",
        nick_tag=nick_tag(),
        token_hash=token_hash(token),
        recovery_hash=code_hash(code),
        locale=req.locale,
    )
    db.add(player)
    db.flush()
    db.add(Profile(player_id=player.id))
    db.commit()
    return GuestResponse(
        player_id=str(player.id),
        token=token,
        nickname=f"{player.nickname}#{player.nick_tag}",
        recovery_code=code,
    )


@router.post("/recover", response_model=GuestResponse)
def recover(req: RecoverRequest, db: Session = Depends(get_db)) -> GuestResponse:
    h = code_hash(req.code)
    player = db.scalar(select(Player).where(Player.recovery_hash == h))
    if player is None or player.deleted_at is not None:
        raise errors.unauthorized("unknown recovery code")
    token = new_token()  # old token revoked by overwrite
    player.token_hash = token_hash(token)
    db.commit()
    return GuestResponse(
        player_id=str(player.id),
        token=token,
        nickname=f"{player.nickname}#{player.nick_tag}",
    )


@router.post("/rename")
def rename(req: RenameRequest, player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    if not _valid_nick(req.nickname):
        raise errors.ApiError(422, "bad_nickname", "nickname rejected by filter")
    player.nickname = req.nickname
    player.last_seen_at = datetime.now(timezone.utc)
    db.commit()
    return {"nickname": f"{player.nickname}#{player.nick_tag}"}


@router.post("/recovery-code")
def recovery_code(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    code = new_recovery_code()
    player.recovery_hash = code_hash(code)
    db.commit()
    return {"recovery_code": code}


@router.get("/me")
def me(player: Player = Depends(current_player)) -> dict:
    return {
        "player_id": str(player.id),
        "short_code": player.short_code,
        "nickname": f"{player.nickname}#{player.nick_tag}",
        "locale": player.locale,
    }


@router.delete("/me")
def delete_me(player: Player = Depends(current_player), db: Session = Depends(get_db)) -> dict:
    player.deleted_at = datetime.now(timezone.utc)
    player.token_hash = token_hash(new_token())  # invalidate
    db.commit()
    return {"deleted": True}