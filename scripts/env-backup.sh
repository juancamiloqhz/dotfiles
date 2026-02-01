#!/usr/bin/env bash
set -euo pipefail

DEV_DIR="$HOME/Dev"
BACKUP_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups"
BACKUP_FILE="$BACKUP_DIR/env-backup.enc"
LOG_DIR="$HOME/.local/share/dotfiles-backup"
LOG_FILE="$LOG_DIR/backup.log"

mkdir -p "$LOG_DIR"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; }

# Load passphrase from ~/.secrets
if [ -f "$HOME/.secrets" ]; then
  source "$HOME/.secrets"
fi

if [ -z "${ENV_BACKUP_PASSPHRASE:-}" ]; then
  log "ENV BACKUP SKIP: ENV_BACKUP_PASSPHRASE not set in ~/.secrets"
  echo "ERROR: ENV_BACKUP_PASSPHRASE not set. Add it to ~/.secrets" >&2
  exit 1
fi

if [ ! -d "$DEV_DIR" ]; then
  log "ENV BACKUP SKIP: $DEV_DIR does not exist"
  exit 0
fi

log "=== Env backup started ==="

# Find all .env* files, excluding junk directories
TMPDIR_BACKUP="$(mktemp -d)"
MANIFEST="$TMPDIR_BACKUP/manifest.txt"

find "$DEV_DIR" \
  -name '.env*' \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/.next/*' \
  -not -path '*/.turbo/*' \
  -not -path '*/vendor/*' \
  -not -path '*/.cache/*' \
  -type f \
  > "$MANIFEST" 2>/dev/null || true

FILE_COUNT=$(wc -l < "$MANIFEST" | tr -d ' ')

if [ "$FILE_COUNT" -eq 0 ]; then
  log "ENV BACKUP: No .env files found in $DEV_DIR"
  rm -rf "$TMPDIR_BACKUP"
  exit 0
fi

log "ENV BACKUP: Found $FILE_COUNT .env file(s)"

# Create tar archive with paths relative to ~/Dev
tar -cf "$TMPDIR_BACKUP/env-archive.tar" \
  -C "$DEV_DIR" \
  --files-from <(sed "s|^$DEV_DIR/||" "$MANIFEST") \
  2>> "$LOG_FILE"

# Encrypt with openssl
mkdir -p "$BACKUP_DIR"
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in "$TMPDIR_BACKUP/env-archive.tar" \
  -out "$BACKUP_FILE" \
  -pass pass:"$ENV_BACKUP_PASSPHRASE" \
  2>> "$LOG_FILE"

# Cleanup
rm -rf "$TMPDIR_BACKUP"

log "ENV BACKUP: Encrypted $FILE_COUNT file(s) → $BACKUP_FILE"
log "=== Env backup finished ==="
