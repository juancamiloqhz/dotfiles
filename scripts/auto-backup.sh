#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$HOME/.local/share/dotfiles-backup"
LOG_FILE="$LOG_DIR/backup.log"
OVERALL_STATUS=0
CREATED_COMMIT=false
SKIP_GIT="${DOTFILES_AUTO_BACKUP_SKIP_GIT:-false}"
AUTO_BACKUP_TEMP_DIR="$(mktemp -d)"

mkdir -p "$LOG_DIR"

cleanup() {
  if [ -d "$AUTO_BACKUP_TEMP_DIR" ]; then
    rm -rf -- "$AUTO_BACKUP_TEMP_DIR"
  fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; }

record_failure() {
  OVERALL_STATUS=1
  log "ERROR: $1"
}

log "=== Backup started ==="

# Generated package snapshot
if command -v brew &>/dev/null; then
  log "Exporting Brewfile..."
  if brew bundle dump --file="$AUTO_BACKUP_TEMP_DIR/Brewfile" --force >> "$LOG_FILE" 2>&1; then
    install -m 644 "$AUTO_BACKUP_TEMP_DIR/Brewfile" "$DOTFILES_DIR/Brewfile"
  else
    record_failure "Brewfile export failed"
  fi
else
  record_failure "brew not found; Brewfile was not updated"
fi

# Generated editor-extension snapshot
if command -v cursor &>/dev/null; then
  log "Exporting Cursor extensions..."
  if cursor --list-extensions > "$AUTO_BACKUP_TEMP_DIR/extensions.txt" 2>> "$LOG_FILE"; then
    install -m 644 "$AUTO_BACKUP_TEMP_DIR/extensions.txt" "$DOTFILES_DIR/cursor/extensions.txt"
  else
    record_failure "Cursor extension export failed"
  fi
else
  record_failure "cursor not found; extension list was not updated"
fi

# Encrypted .env backup to iCloud. Failure is part of the overall job status.
log "Running env backup..."
if bash "$DOTFILES_DIR/scripts/env-backup.sh" >> "$LOG_FILE" 2>&1; then
  log "Env backup completed"
else
  record_failure "Env backup failed; encrypted archive was not updated"
fi

# Only the two generated snapshots may be committed automatically. Refuse to
# touch the index when the user already has staged work.
if [ "$SKIP_GIT" = true ]; then
  log "SKIP: automatic Git commit disabled for this run"
elif ! command -v git &>/dev/null; then
  record_failure "git not found; generated snapshots were not committed"
else
  cd "$DOTFILES_DIR"

  if ! git diff --cached --quiet; then
    record_failure "Git index already contains staged work; skipped automatic commit"
  else
    git add -- Brewfile cursor/extensions.txt

    if ! git diff --cached --quiet; then
      if git commit -m "auto-backup: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1; then
        CREATED_COMMIT=true
        log "Generated snapshots committed"
      else
        record_failure "Git commit failed"
      fi
    else
      log "No generated changes to commit"
    fi

    if [ "$CREATED_COMMIT" = true ]; then
      if git remote | grep -q .; then
        if git push >> "$LOG_FILE" 2>&1; then
          log "Pushed generated snapshot commit"
        else
          record_failure "Git push failed"
        fi
      else
        log "SKIP: no remote configured"
      fi
    fi
  fi
fi

if [ "$OVERALL_STATUS" -ne 0 ]; then
  log "=== Backup finished with errors ==="
  exit "$OVERALL_STATUS"
fi

log "=== Backup finished successfully ==="
