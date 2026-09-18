#!/usr/bin/env bash
set -euo pipefail

SESSION_DIR="/Users/ajuenemann/Library/Mobile Documents/com~apple~CloudDocs/telegram-archiver/data/session"
URL_FILE="$SESSION_DIR/qr_login_url.txt"

echo "Warte auf QR-URL in $URL_FILE ..."
echo "Scanne den QR-Code direkt aus diesem Terminalfenster in Telegram > Einstellungen > Geraete > Desktop-Geraet verknuepfen"

last=""
while true; do
  if [[ -f "$URL_FILE" ]]; then
    current="$(cat "$URL_FILE" 2>/dev/null || true)"
    if [[ -n "$current" && "$current" != "$last" ]]; then
      clear
      echo "Neuer QR-Code (live):"
      qrencode -t ANSIUTF8 -l M "$current"
      echo
      echo "Wenn gescannt: im Login-Terminal die 2FA-Abfrage abwarten und dort eingeben."
      last="$current"
    fi
  fi
  sleep 1
done