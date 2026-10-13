#!/usr/bin/env bash
# Move the archive (DATA_DIR) to another machine or disk, and verify the copy.
#
#   scripts/move_archive.sh check  [DATA_DIR]            # health check of the source
#   scripts/move_archive.sh sync   DEST [--final]        # copy; DEST = /mnt/disk/x or user@host:/path
#   scripts/move_archive.sh verify DEST_DATA_DIR         # run on the NEW machine after the copy
#
# Workflow: run `sync` while the stack is up (warm pass, may be inconsistent), then stop the
# containers yourself and run `sync --final` (refuses while telegram-backup runs).
# Symlinks (DEDUPLICATE_MEDIA) are kept as-is; they are relative, so the tree is relocatable.
set -euo pipefail

cmd="${1:-}"
[ -n "$cmd" ] || { sed -n '2,10p' "$0"; exit 1; }
shift

resolve_data_dir() {
  local d="${1:-${DATA_DIR:-}}"
  if [ -z "$d" ] && [ -f .env ]; then
    d="$(grep -E '^DATA_DIR=' .env | tail -1 | cut -d= -f2- | tr -d "\"'")"
  fi
  echo "${d:-./data}"
}

# Dangling or absolute symlinks break after a move.
check_links() {
  local dir="$1" dangling absolute
  dangling="$(find "$dir" -type l ! -exec test -e {} \; -print | wc -l | tr -d ' ')"
  absolute="$(find "$dir" -type l -lname '/*' | wc -l | tr -d ' ')"
  echo "symlinks: $(find "$dir" -type l | wc -l | tr -d ' ') (dangling: $dangling, absolute: $absolute)"
  [ "$dangling" = 0 ] && [ "$absolute" = 0 ]
}

check_db() {
  local db
  for db in "$1"/backups/*.db; do
    [ -f "$db" ] || continue
    echo "integrity $(basename "$db"): $(sqlite3 "file:$db?immutable=1" 'PRAGMA integrity_check;')"
  done
}

summary() {
  echo "size: $(du -sh "$1" | cut -f1), files: $(find "$1" -type f | wc -l | tr -d ' ')"
}

case "$cmd" in
  check|verify)
    dir="$(resolve_data_dir "${1:-}")"
    [ -d "$dir" ] || { echo "not a directory: $dir" >&2; exit 1; }
    echo "data dir: $dir"
    summary "$dir"
    check_links "$dir"
    check_db "$dir"
    ;;
  sync)
    dest="${1:?destination required}"
    final="${2:-}"
    src="$(resolve_data_dir)"
    if [ "$final" = "--final" ] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'telegram-backup'; then
      echo "telegram-backup is still running; stop it first (final copy needs a quiescent DB)." >&2
      exit 1
    fi
    check_links "$src" || { echo "fix the symlinks above first" >&2; exit 1; }
    rsync -a --partial --stats --exclude '.DS_Store' "$src"/ "$dest"/
    echo "done. On the target run: scripts/move_archive.sh verify <data dir>"
    echo "also copy .env (secrets!) and keep the same image version; compare with: summary above"
    summary "$src"
    ;;
  *)
    echo "unknown command: $cmd" >&2
    exit 1
    ;;
esac
