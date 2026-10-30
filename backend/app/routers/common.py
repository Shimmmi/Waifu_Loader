from fastapi import APIRouter

from ..config import settings
from ..schemas import ConfigResponse, TimeResponse
from ..security import server_time

router = APIRouter(tags=["common"])


@router.get("/config", response_model=ConfigResponse)
def get_config() -> ConfigResponse:
    return ConfigResponse(
        min_client_version=settings.min_client_version,
        sim_versions_supported=settings.sim_versions,
        global_scale=settings.global_scale,
        features={"daily": True, "tender": True, "pvp": True, "unions": True},
    )


@router.get("/time", response_model=TimeResponse)
def get_time() -> TimeResponse:
    return TimeResponse(server_time=server_time())


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/news")
def news() -> dict:
    return {"news": []}