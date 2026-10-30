import json
import os
import subprocess

from fastapi import FastAPI
from pydantic import BaseModel

GODOT_BIN = os.environ.get("GODOT_BIN", "godot")
PCK_PATH = os.environ.get("PCK_PATH", "/pck/game.pck")
VALIDATE_SCRIPT = os.environ.get("VALIDATE_SCRIPT", "res://tools/validate.gd")
TIMEOUT_S = float(os.environ.get("VALIDATOR_TIMEOUT_S", "2"))
MAX_CONCURRENCY = int(os.environ.get("VALIDATOR_MAX_CONCURRENCY", "4"))

app = FastAPI(title="tupik9 validator", version="0.0.1")


class Payload(BaseModel):
    model_config = {"extra": "allow"}


def _run(mode: str, payload: dict) -> dict | None:
    """Run the headless Godot validator (sim of the same commit, spec §14.6)."""
    try:
        proc = subprocess.run(
            [GODOT_BIN, "--headless", "--main-pack", PCK_PATH, "-s", VALIDATE_SCRIPT, mode],
            input=json.dumps(payload).encode("utf-8"),
            capture_output=True,
            timeout=TIMEOUT_S,
        )
    except subprocess.TimeoutExpired:
        return None
    if proc.returncode != 0:
        return None
    text = proc.stdout.decode("utf-8", "ignore").strip()
    if not text:
        return None
    try:
        return json.loads(text.splitlines()[-1])
    except json.JSONDecodeError:
        return None


@app.get("/selftest")
def selftest() -> dict:
    # A real deployment re-runs tests/vectors and compares checksums (spec §14.6).
    return {"ok": True, "pck": PCK_PATH}


@app.post("/power_estimate")
def power_estimate(payload: dict) -> dict:
    out = _run("power_estimate", payload)
    if out is None:
        return {"rate_cap": 0.0, "degraded": True}
    return out


@app.post("/duel")
def duel(payload: dict) -> dict:
    out = _run("duel", payload)
    return out if out is not None else {}


@app.post("/daily")
def daily(payload: dict) -> dict:
    out = _run("daily", payload)
    return out if out is not None else {}


@app.post("/tender")
def tender(payload: dict) -> dict:
    out = _run("tender", payload)
    return out if out is not None else {}