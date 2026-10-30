import hashlib
import secrets
import time

_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # Crockford base32


def new_token() -> str:
    """256-bit bearer token (spec §14.3)."""
    return secrets.token_urlsafe(32)


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def new_recovery_code() -> str:
    """16-char Crockford base32 recovery code (spec §13.2)."""
    return "".join(secrets.choice(_ALPHABET) for _ in range(16))


def code_hash(code: str) -> str:
    return hashlib.sha256(code.strip().upper().encode("utf-8")).hexdigest()


def short_code() -> str:
    """Short public id used in profile URLs."""
    return "".join(secrets.choice(_ALPHABET) for _ in range(8))


def nick_tag() -> str:
    return f"{secrets.randbelow(10000):04d}"


def server_time() -> int:
    return int(time.time())


class RateLimiter:
    """Tiny in-memory sliding-window limiter (Redis optional, spec §14.1)."""

    def __init__(self) -> None:
        self._hits: dict[str, list[float]] = {}

    def allow(self, key: str, limit: int, window_s: float = 60.0) -> bool:
        now = time.time()
        bucket = [t for t in self._hits.get(key, []) if now - t < window_s]
        if len(bucket) >= limit:
            self._hits[key] = bucket
            return False
        bucket.append(now)
        self._hits[key] = bucket
        return True


rate_limiter = RateLimiter()