#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
LOG_DIR="$HOME/.local/share/dotfiles-backup"
LOG_FILE="$LOG_DIR/backup.log"

mkdir -p "$LOG_DIR"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; }

log "=== Backup started ==="

# Guard: required tools
for cmd in brew cursor git; do
  if ! command -v "$cmd" &>/dev/null; then
    log "SKIP: $cmd not found"
    exit 0
  fi
done

# Re-export Brewfile
log "Exporting Brewfile..."
brew bundle dump --file="$DOTFILES_DIR/Brewfile" --force >> "$LOG_FILE" 2>&1

# Re-export Cursor extensions
log "Exporting Cursor extensions..."
cursor --list-extensions > "$DOTFILES_DIR/cursor/extensions.txt" 2>> "$LOG_FILE"

# Stage changes
cd "$DOTFILES_DIR"
git add -A

# Commit only if there are staged changes
if ! git diff --cached --quiet; then
  git commit -m "auto-backup: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>&1
  log "Changes committed"

  # Push only if a remote is configured
  if git remote | grep -q .; then
    git push >> "$LOG_FILE" 2>&1
    log "Pushed to remote"
  else
    log "SKIP: no remote configured, skipping push"
  fi
else
  log "No changes to commit"
fi

log "=== Backup finished ==="
