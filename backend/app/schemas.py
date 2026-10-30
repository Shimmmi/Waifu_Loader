from pydantic import BaseModel, ConfigDict, Field


# -------------------------------------------------------------------- common
class ConfigResponse(BaseModel):
    min_client_version: str
    sim_versions_supported: list[int]
    global_scale: float
    features: dict


class TimeResponse(BaseModel):
    server_time: int


# -------------------------------------------------------------------- account
class GuestRequest(BaseModel):
    client_version: str
    locale: str = "ru"


class GuestResponse(BaseModel):
    player_id: str
    token: str
    nickname: str
    recovery_code: str | None = None


class RecoverRequest(BaseModel):
    code: str


class RenameRequest(BaseModel):
    nickname: str


# -------------------------------------------------------------------- save
class SaveMeta(BaseModel):
    lifetime_t: float = 0.0
    prestige_count: int = 0
    rank: int = 1
    playtime_s: float = 0.0
    schema_v: int = 1


class SavePutRequest(BaseModel):
    base_revision: int = 0
    save_b64: str
    meta: SaveMeta


class SavePutResponse(BaseModel):
    revision: int


class SaveGetResponse(BaseModel):
    revision: int
    save_b64: str
    meta: dict
    updated_at: int


# -------------------------------------------------------------------- telemetry
class PowerSnapshot(BaseModel):
    model_config = ConfigDict(extra="allow")

    dock: list[int] = Field(default_factory=list)
    storage: list[int] = Field(default_factory=list)
    crew: list[dict] = Field(default_factory=list)
    tree: dict = Field(default_factory=dict)


class TelemetryRequest(BaseModel):
    seq: int
    window_start: int
    window_end: int
    delta_tonnes: float
    best_tpm: float
    gold_count: int = 0
    shifts: int = 0
    power_snapshot: PowerSnapshot | None = None


class TelemetryResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    accepted: bool
    hold: bool
    server_time: int
    global_status: dict = Field(alias="global")


# -------------------------------------------------------------------- daily / tender
class DailySubmitRequest(BaseModel):
    daily_seed: str
    assignment: list[dict] = Field(default_factory=list)
    event_choices: list[dict] = Field(default_factory=list)
    mode: str = "x1"
    rush_times: list[float] = Field(default_factory=list)


class TenderSubmitRequest(BaseModel):
    tender_id: str
    plan: dict = Field(default_factory=dict)


# -------------------------------------------------------------------- pvp
class PvpAttackRequest(BaseModel):
    opponent_id: str
    tactic: str = "balance"


class PvpDefenseRequest(BaseModel):
    defense: dict
    tactic: str = "balance"


# -------------------------------------------------------------------- unions / social
class UnionCreateRequest(BaseModel):
    name: str
    emblem: int = 0
    description: str = ""
    join_mode: str = "open"


class DonateRequest(BaseModel):
    amount: int


class ReportRequest(BaseModel):
    target_type: str
    target_id: str
    reason: str