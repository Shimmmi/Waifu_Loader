# Backend — «Космо-грузчицы» (tupik9)

FastAPI + PostgreSQL + headless-Godot validator, matching the frozen client
contract in [`../docs/API.md`](../docs/API.md) (spec §14).

Deploys to `/opt/tupik9/` on the VPS as a **separate docker compose project**
(`tupik9`), with the `api` container bound to **`127.0.0.1:8095`** (the spec's
8090 was already taken by another host service) and nginx proxying
`location /tupik9/api/` to it. Nothing else on the host is touched.

## Layout

```
backend/
  app/
    main.py          FastAPI app, CORS, router wiring, /health
    config.py        env settings (pydantic-settings)
    db.py            SQLAlchemy engine/session
    models.py        ORM tables (§14.4)
    schemas.py       Pydantic v2 request/response models
    security.py      token issue/hash, idempotency, rate-limit helper
    deps.py          request deps (db, current player)
    validator.py     client for the headless Godot validator (§14.6)
    scheduler.py     APScheduler jobs (§14.7)
    manage.py        admin CLI (ban/rename/grant/stats)
    routers/         one module per endpoint group
  migrations/        Alembic
  validator/         headless Godot validator container (validate.gd)
  docker-compose.yml
  Dockerfile
  nginx.conf.snippet
  .env.example
```

## Local run

```bash
cp .env.example .env
docker compose up -d db
alembic upgrade head
docker compose up api          # http://127.0.0.1:8090/health
```

## Deploy (later step, needs VPS access — spec §14.10)

1. `install -d /opt/tupik9` and copy this repo there.
2. `cp /etc/nginx/sites-available/waifu-bot /root/backup/waifu-bot.$(date +%F)`.
3. Add one line inside the `shimmirpgbot.ru` server block:
   `include /opt/tupik9/nginx.conf.snippet;`
4. Build the Godot PCK for the validator of the **same commit** as the client.
5. `cd /opt/tupik9 && docker compose up -d --build`.
6. `nginx -t && systemctl reload nginx` (never restart).
7. Verify `curl https://shimmirpgbot.ru/tupik9/api/v1/health`.

Do not stop or reconfigure the host's existing services (`/elevators/`, bots,
`waifu_loader`, …).