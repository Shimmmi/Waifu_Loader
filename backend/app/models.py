import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


def _uuid() -> uuid.UUID:
    return uuid.uuid4()


class Player(Base):
    __tablename__ = "players"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    short_code: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    nickname: Mapped[str] = mapped_column(String(32))
    nick_tag: Mapped[str] = mapped_column(String(8), default="0000")
    token_hash: Mapped[str] = mapped_column(String(64), index=True)
    recovery_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    locale: Mapped[str] = mapped_column(String(8), default="ru")
    flags: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Save(Base):
    __tablename__ = "saves"

    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    revision: Mapped[int] = mapped_column(Integer, default=0)
    blob: Mapped[bytes] = mapped_column(LargeBinary)
    meta: Mapped[dict] = mapped_column(JSONB, default=dict)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ProgressWindow(Base):
    __tablename__ = "progress_windows"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    seq: Mapped[int] = mapped_column(Integer)
    window_start: Mapped[int] = mapped_column(Integer)
    window_end: Mapped[int] = mapped_column(Integer)
    delta_tonnes: Mapped[float] = mapped_column(Float, default=0.0)
    best_tpm: Mapped[float] = mapped_column(Float, default=0.0)
    gold_count: Mapped[int] = mapped_column(Integer, default=0)
    accepted: Mapped[bool] = mapped_column(Boolean, default=False)
    reason: Mapped[str | None] = mapped_column(String(64), nullable=True)


class BoardEntry(Base):
    __tablename__ = "board_entries"
    __table_args__ = (Index("ix_board_score", "board_id", "period_key", "score"),)

    board_id: Mapped[str] = mapped_column(String(32), primary_key=True)
    period_key: Mapped[str] = mapped_column(String(32), primary_key=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    score: Mapped[float] = mapped_column(Float, default=0.0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Profile(Base):
    __tablename__ = "profiles"

    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    title: Mapped[str] = mapped_column(String(32), default="")
    frame: Mapped[str] = mapped_column(String(32), default="")
    avatar: Mapped[str] = mapped_column(String(32), default="")
    rank: Mapped[int] = mapped_column(Integer, default=1)
    lifetime_log10: Mapped[float] = mapped_column(Float, default=0.0)
    reorg_count: Mapped[int] = mapped_column(Integer, default=0)
    showcase: Mapped[dict] = mapped_column(JSONB, default=dict)
    terminal_snapshot: Mapped[dict] = mapped_column(JSONB, default=dict)
    respect_count: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class Friendship(Base):
    __tablename__ = "friends"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    a_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    b_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(16), default="pending")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Union(Base):
    __tablename__ = "unions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String(20), unique=True)
    emblem: Mapped[int] = mapped_column(Integer, default=0)
    description: Mapped[str] = mapped_column(String(80), default="")
    join_mode: Mapped[str] = mapped_column(String(16), default="open")
    fund: Mapped[int] = mapped_column(Integer, default=0)
    upgrades: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UnionMember(Base):
    __tablename__ = "union_members"

    union_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("unions.id", ondelete="CASCADE"), primary_key=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    role: Mapped[str] = mapped_column(String(16), default="member")
    week_contribution: Mapped[float] = mapped_column(Float, default=0.0)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class UnionGoal(Base):
    __tablename__ = "union_goals"

    union_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("unions.id", ondelete="CASCADE"), primary_key=True)
    week_key: Mapped[str] = mapped_column(String(16), primary_key=True)
    target: Mapped[float] = mapped_column(Float, default=0.0)
    progress: Mapped[float] = mapped_column(Float, default=0.0)


class UnionBoardPost(Base):
    __tablename__ = "union_board"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    union_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("unions.id", ondelete="CASCADE"), index=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"))
    phrase_id: Mapped[int] = mapped_column(Integer, default=0)
    sticker_id: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class PvpProfile(Base):
    __tablename__ = "pvp_profiles"

    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    rating: Mapped[int] = mapped_column(Integer, default=1000)
    league: Mapped[str] = mapped_column(String(16), default="bronze")
    passes: Mapped[int] = mapped_column(Integer, default=5)
    passes_ts: Mapped[int] = mapped_column(Integer, default=0)
    defense: Mapped[dict] = mapped_column(JSONB, default=dict)
    defense_tactic: Mapped[str] = mapped_column(String(16), default="balance")
    defense_locked_until: Mapped[int] = mapped_column(Integer, default=0)
    season_key: Mapped[str] = mapped_column(String(16), default="")
    wins: Mapped[int] = mapped_column(Integer, default=0)
    losses: Mapped[int] = mapped_column(Integer, default=0)


class PvpMatch(Base):
    __tablename__ = "pvp_matches"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    attacker: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"))
    defender: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"))
    defender_is_bot: Mapped[bool] = mapped_column(Boolean, default=False)
    seed: Mapped[int] = mapped_column(Integer, default=0)
    rule: Mapped[str] = mapped_column(String(32), default="standard")
    tactics: Mapped[dict] = mapped_column(JSONB, default=dict)
    result: Mapped[dict] = mapped_column(JSONB, default=dict)
    replay: Mapped[bytes] = mapped_column(LargeBinary, default=b"")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DailySeed(Base):
    __tablename__ = "daily_seeds"

    day_key: Mapped[str] = mapped_column(String(16), primary_key=True)
    seed: Mapped[str] = mapped_column(String(32))
    preset: Mapped[dict] = mapped_column(JSONB, default=dict)


class DailyRun(Base):
    __tablename__ = "daily_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    day_key: Mapped[str] = mapped_column(String(16), index=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    plan: Mapped[dict] = mapped_column(JSONB, default=dict)
    score: Mapped[float] = mapped_column(Float, default=0.0)
    valid: Mapped[bool] = mapped_column(Boolean, default=False)


class GlobalGoal(Base):
    __tablename__ = "global_goal"

    stage: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    progress: Mapped[float] = mapped_column(Float, default=0.0)
    target: Mapped[float] = mapped_column(Float, default=1.0e9)


class GlobalContrib(Base):
    __tablename__ = "global_contrib"

    stage: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    amount: Mapped[float] = mapped_column(Float, default=0.0)


class InboxItem(Base):
    __tablename__ = "inbox"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=_uuid)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(32))
    payload: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"))
    target_type: Mapped[str] = mapped_column(String(16))
    target_id: Mapped[str] = mapped_column(String(64))
    reason: Mapped[str] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class IdempotencyKey(Base):
    __tablename__ = "idempotency_keys"

    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    player_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"))
    method: Mapped[str] = mapped_column(String(8))
    path: Mapped[str] = mapped_column(String(128))
    status: Mapped[int] = mapped_column(Integer, default=200)
    response: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())