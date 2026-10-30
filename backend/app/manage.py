"""Admin CLI (spec §14.8): manage.py <command> [args].

Commands: stats, ban <short_code>, unban <short_code>, rename <short_code> <nick>,
grant <short_code> <tokens>, hide-union <union_id>.
"""

import argparse
import sys
from datetime import datetime, timezone

from sqlalchemy import func, select

from .db import SessionLocal
from .models import Player, Save, Union


def _by_code(db, code: str) -> Player:
    player = db.scalar(select(Player).where(Player.short_code == code))
    if player is None:
        print(f"no player with code {code}")
        sys.exit(1)
    return player


def cmd_stats(db) -> None:
    players = db.scalar(select(func.count()).select_from(Player)) or 0
    saves = db.scalar(select(func.count()).select_from(Save)) or 0
    unions = db.scalar(select(func.count()).select_from(Union)) or 0
    print(f"players={players} saves={saves} unions={unions}")


def cmd_ban(db, code: str) -> None:
    p = _by_code(db, code)
    p.flags = {**(p.flags or {}), "banned": True}
    db.commit()
    print(f"banned {code}")


def cmd_unban(db, code: str) -> None:
    p = _by_code(db, code)
    flags = dict(p.flags or {})
    flags["banned"] = False
    p.flags = flags
    db.commit()
    print(f"unbanned {code}")


def cmd_rename(db, code: str, nick: str) -> None:
    p = _by_code(db, code)
    p.nickname = nick
    db.commit()
    print(f"renamed {code} -> {nick}")


def cmd_grant(db, code: str, tokens: int) -> None:
    p = _by_code(db, code)
    # Tokens live in the client save; grants go through the inbox in prod.
    print(f"(placeholder) would grant {tokens} tokens to {code}")


def cmd_hide_union(db, union_id: str) -> None:
    print(f"(placeholder) would hide union {union_id}")


def main() -> None:
    parser = argparse.ArgumentParser(prog="manage.py")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("stats")
    for name in ("ban", "unban"):
        p = sub.add_parser(name)
        p.add_argument("code")
    p = sub.add_parser("rename")
    p.add_argument("code")
    p.add_argument("nick")
    p = sub.add_parser("grant")
    p.add_argument("code")
    p.add_argument("tokens", type=int)
    p = sub.add_parser("hide-union")
    p.add_argument("union_id")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        if args.cmd == "stats":
            cmd_stats(db)
        elif args.cmd == "ban":
            cmd_ban(db, args.code)
        elif args.cmd == "unban":
            cmd_unban(db, args.code)
        elif args.cmd == "rename":
            cmd_rename(db, args.code, args.nick)
        elif args.cmd == "grant":
            cmd_grant(db, args.code, args.tokens)
        elif args.cmd == "hide-union":
            cmd_hide_union(db, args.union_id)
    finally:
        db.close()


if __name__ == "__main__":
    main()