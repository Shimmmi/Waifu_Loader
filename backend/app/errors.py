from fastapi import HTTPException


class ApiError(HTTPException):
    """HTTPException whose body uses the uniform {error:{code,message}} envelope
    (spec §14.5)."""

    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(
            status_code=status_code,
            detail={"error": {"code": code, "message": message}},
        )


def not_found(message: str = "not found") -> ApiError:
    return ApiError(404, "not_found", message)


def unauthorized(message: str = "unauthorized") -> ApiError:
    return ApiError(401, "unauthorized", message)


def conflict(code: str, message: str, extra: dict | None = None) -> ApiError:
    err = ApiError(409, code, message)
    if extra:
        err.detail["extra"] = extra  # type: ignore[index]
    return err


def upgrade_required(message: str = "client update required") -> ApiError:
    return ApiError(426, "upgrade_required", message)


def rate_limited(message: str = "rate limited") -> ApiError:
    return ApiError(429, "rate_limited", message)