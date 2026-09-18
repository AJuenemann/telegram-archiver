#!/usr/bin/env bash
# Starts the Telegram Archive stack (backup + viewer) reliably:
# frees a stale port from a previous run of THIS project, brings the
# stack up, waits for the viewer to become healthy, then opens it
# in the default browser. Never touches ports held by unrelated processes.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

ENV_FILE="$PROJECT_DIR/.env"
VIEWER_PORT="8000"
if [[ -f "$ENV_FILE" ]]; then
    port_from_env="$(grep -E '^VIEWER_PORT=' "$ENV_FILE" | tail -n1 | cut -d= -f2-)"
    [[ -n "$port_from_env" ]] && VIEWER_PORT="$port_from_env"
fi

VIEWER_URL="http://127.0.0.1:${VIEWER_PORT}"

log() { printf '[start] %s\n' "$1"; }

port_pids() {
    lsof -ti "tcp:${VIEWER_PORT}" -sTCP:LISTEN 2>/dev/null || true
}

is_our_container_on_port() {
    # True if the only thing listening on VIEWER_PORT is Docker itself
    # (docker-proxy / com.docker.backend), i.e. a stale container from a
    # previous run of this project, not some unrelated host process.
    local pid cmd
    for pid in $(port_pids); do
        cmd="$(ps -o comm= -p "$pid" 2>/dev/null || true)"
        case "$cmd" in
            *docker-proxy*|*com.docker.backend*|*com.docker*) continue ;;
            *) return 1 ;;
        esac
    done
    return 0
}

log "Checking port ${VIEWER_PORT}..."
if [[ -n "$(port_pids)" ]]; then
    if is_our_container_on_port; then
        log "Port ${VIEWER_PORT} is held by a previous run of this project. Cleaning up..."
        docker compose down --remove-orphans || true
    else
        echo "[start] ERROR: Port ${VIEWER_PORT} is in use by another (non-Docker) process." >&2
        echo "[start] Free it manually or set VIEWER_PORT in .env to a different port, then retry." >&2
        lsof -i "tcp:${VIEWER_PORT}" -sTCP:LISTEN >&2 || true
        exit 1
    fi
fi

log "Building and starting containers..."
docker compose up -d --build

log "Waiting for the viewer to become healthy..."
attempts=60
until curl -fsS -o /dev/null "$VIEWER_URL" 2>/dev/null; do
    attempts=$((attempts - 1))
    if [[ "$attempts" -le 0 ]]; then
        echo "[start] ERROR: Viewer did not become reachable at ${VIEWER_URL} in time." >&2
        echo "[start] Check logs with: docker compose logs telegram-viewer" >&2
        exit 1
    fi
    sleep 2
done

log "Viewer is up: ${VIEWER_URL}"

if command -v open >/dev/null 2>&1; then
    open "$VIEWER_URL"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$VIEWER_URL"
else
    log "Open this URL manually: ${VIEWER_URL}"
fi

log "Done."
