import httpx

from .config import settings


def _call(path: str, payload: dict) -> dict | None:
    """Call the headless Godot validator (spec §14.6). Returns None on failure
    (validator degraded -> caller applies its degradation policy)."""
    url = settings.validator_url.rstrip("/") + path
    try:
        resp = httpx.post(url, json=payload, timeout=settings.validator_timeout_s)
    except Exception:
        return None
    if resp.status_code != 200:
        return None
    try:
        return resp.json()
    except Exception:
        return None


def power_estimate(snapshot: dict) -> float | None:
    out = _call("/power_estimate", snapshot)
    if out and "rate_cap" in out:
        try:
            return float(out["rate_cap"])
        except (TypeError, ValueError):
            return None
    return None


def duel(payload: dict) -> dict | None:
    return _call("/duel", payload)


def daily(payload: dict) -> dict | None:
    return _call("/daily", payload)


def tender(payload: dict) -> dict | None:
    return _call("/tender", payload)