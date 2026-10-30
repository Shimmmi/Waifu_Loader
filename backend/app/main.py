from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import settings
from .deps import check_client_version
from .errors import ApiError
from .routers import (
    auth,
    boards,
    common,
    daily,
    friends,
    global_goal,
    inbox,
    profile,
    pvp,
    save,
    telemetry,
    tender,
    unions,
)

app = FastAPI(
    title="tupik9 API",
    version="0.0.1",
    docs_url="/docs",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Idempotency-Key",
        "X-Client-Version",
        "X-Sim-Version",
    ],
)


@app.exception_handler(ApiError)
async def _api_error(request: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content=exc.detail)


@app.get("/health")
def root_health() -> dict:
    """Unversioned health used by the docker healthcheck / local runs."""
    return {"status": "ok"}


# Client paths are https://<host>/tupik9/api/v1/*; nginx strips /tupik9/api/,
# so the app serves everything under /v1 (spec §14.3).
for module in (
    common,
    auth,
    save,
    telemetry,
    boards,
    profile,
    friends,
    daily,
    tender,
    pvp,
    unions,
    global_goal,
    inbox,
):
    app.include_router(
        module.router,
        prefix="/v1",
        dependencies=[Depends(check_client_version)],
    )