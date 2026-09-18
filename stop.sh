#!/usr/bin/env bash
# Stops the Telegram Archive stack reliably and frees its port.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

ENV_FILE="$PROJECT_DIR/.env"
VIEWER_PORT="8000"
if [[ -f "$ENV_FILE" ]]; then
    port_from_env="$(grep -E '^VIEWER_PORT=' "$ENV_FILE" | tail -n1 | cut -d= -f2-)"
    [[ -n "$port_from_env" ]] && VIEWER_PORT="$port_from_env"
fi

log() { printf '[stop] %s\n' "$1"; }

log "Stopping containers..."
docker compose down --remove-orphans

port_pids() {
    lsof -ti "tcp:${VIEWER_PORT}" -sTCP:LISTEN 2>/dev/null || true
}

if [[ -n "$(port_pids)" ]]; then
    echo "[stop] WARNING: Port ${VIEWER_PORT} is still in use by another process (not touched):" >&2
    lsof -i "tcp:${VIEWER_PORT}" -sTCP:LISTEN >&2 || true
else
    log "Port ${VIEWER_PORT} is free."
fi

log "Done."
