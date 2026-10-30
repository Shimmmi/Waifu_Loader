# Headless Godot validator (spec §14.6). The Godot build must match the client
# commit; mount the exported PCK at /pck/game.pck.
#
# Base image carries a headless Godot Linux binary; override the version tag to
# the one matching the game (4.7.x for this project).
FROM python:3.12-slim

ARG GODOT_VERSION=4.7.2
ENV GODOT_BIN=godot \
    PCK_PATH=/pck/game.pck \
    VALIDATE_SCRIPT=res://tools/validate.gd \
    VALIDATOR_TIMEOUT_S=2 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl unzip ca-certificates \
    && curl -fsSL -o /tmp/godot.zip \
       "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip /tmp/godot.zip -d /usr/local/bin \
    && mv "/usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip \
    && apt-get purge -y unzip && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir fastapi==0.115.6 "uvicorn[standard]==0.34.0"

WORKDIR /srv
COPY app.py .
EXPOSE 8081
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8081"]