#!/usr/bin/env bash
set -euo pipefail

DEV_DIR="${DOTFILES_DEV_DIR:-$HOME/Dev}"
BACKUP_FILE="${DOTFILES_ENV_BACKUP_FILE:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups/env-backup.enc}"
BACKUP_DIR="$(dirname "$BACKUP_FILE")"
SECRETS_FILE="${DOTFILES_SECRETS_FILE:-$HOME/.secrets}"
LOG_FILE="${DOTFILES_BACKUP_LOG_FILE:-$HOME/.local/share/dotfiles-backup/backup.log}"
LOG_DIR="$(dirname "$LOG_FILE")"
ENV_BACKUP_TEMP_DIR=""
ENV_BACKUP_PENDING_FILE=""
ENV_BACKUP_WRITE_TEST=""

umask 077
mkdir -p "$LOG_DIR"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG_FILE"; }

cleanup() {
  if [ -n "$ENV_BACKUP_WRITE_TEST" ] && [ -e "$ENV_BACKUP_WRITE_TEST" ]; then
    rm -f -- "$ENV_BACKUP_WRITE_TEST"
  fi
  if [ -n "$ENV_BACKUP_PENDING_FILE" ] && [ -e "$ENV_BACKUP_PENDING_FILE" ]; then
    rm -f -- "$ENV_BACKUP_PENDING_FILE"
  fi
  if [ -n "$ENV_BACKUP_TEMP_DIR" ] && [ -d "$ENV_BACKUP_TEMP_DIR" ]; then
    rm -rf -- "$ENV_BACKUP_TEMP_DIR"
  fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Load passphrase from the machine-local secrets file.
if [ -f "$SECRETS_FILE" ]; then
  source "$SECRETS_FILE"
fi

if [ -z "${ENV_BACKUP_PASSPHRASE:-}" ]; then
  log "ENV BACKUP SKIP: ENV_BACKUP_PASSPHRASE not set in ~/.secrets"
  echo "ERROR: ENV_BACKUP_PASSPHRASE not set. Add it to ~/.secrets" >&2
  exit 1
fi

# Avoid exposing the passphrase in the openssl command-line arguments.
export ENV_BACKUP_PASSPHRASE

if [ ! -d "$DEV_DIR" ]; then
  log "ENV BACKUP SKIP: $DEV_DIR does not exist"
  exit 0
fi

log "=== Env backup started ==="

# Fail before doing expensive work when the scheduled process cannot write to
# the iCloud destination. The temporary probe is removed immediately.
if ! mkdir -p "$BACKUP_DIR"; then
  log "ENV BACKUP ERROR: Cannot create destination directory: $BACKUP_DIR"
  exit 1
fi

ENV_BACKUP_WRITE_TEST="$BACKUP_DIR/.env-backup-write-test.$$"
if ! (umask 077 && : > "$ENV_BACKUP_WRITE_TEST") 2>/dev/null; then
  log "ENV BACKUP ERROR: Cannot write to destination directory: $BACKUP_DIR"
  echo "ERROR: Cannot write encrypted backup to $BACKUP_DIR" >&2
  echo "Grant the LaunchAgent's shell access to iCloud Drive, then retry." >&2
  exit 1
fi
rm -f -- "$ENV_BACKUP_WRITE_TEST"
ENV_BACKUP_WRITE_TEST=""

# Find all .env* files, excluding junk directories
ENV_BACKUP_TEMP_DIR="$(mktemp -d)"
MANIFEST="$ENV_BACKUP_TEMP_DIR/manifest.txt"

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
  exit 0
fi

log "ENV BACKUP: Found $FILE_COUNT .env file(s)"

# Create tar archive with paths relative to ~/Dev
tar -cf "$ENV_BACKUP_TEMP_DIR/env-archive.tar" \
  -C "$DEV_DIR" \
  --files-from <(sed "s|^$DEV_DIR/||" "$MANIFEST") \
  2>> "$LOG_FILE"

# Encrypt locally first so a failed iCloud write never corrupts the previous
# archive. The passphrase is read from the environment, not process arguments.
openssl enc -aes-256-cbc -salt -pbkdf2 \
  -in "$ENV_BACKUP_TEMP_DIR/env-archive.tar" \
  -out "$ENV_BACKUP_TEMP_DIR/env-backup.enc" \
  -pass env:ENV_BACKUP_PASSPHRASE \
  2>> "$LOG_FILE"

# Verify both decryption and tar readability before publishing the new archive.
openssl enc -aes-256-cbc -d -salt -pbkdf2 \
  -in "$ENV_BACKUP_TEMP_DIR/env-backup.enc" \
  -out "$ENV_BACKUP_TEMP_DIR/verify.tar" \
  -pass env:ENV_BACKUP_PASSPHRASE \
  2>> "$LOG_FILE"
tar -tf "$ENV_BACKUP_TEMP_DIR/verify.tar" >/dev/null

# Copy to a sibling temporary file, rotate the previous archive, then rename.
# The final rename is atomic within the destination directory.
ENV_BACKUP_PENDING_FILE="$BACKUP_DIR/.env-backup.enc.tmp.$$"
cp "$ENV_BACKUP_TEMP_DIR/env-backup.enc" "$ENV_BACKUP_PENDING_FILE"
chmod 600 "$ENV_BACKUP_PENDING_FILE"

if [ -f "$BACKUP_FILE" ]; then
  cp -p "$BACKUP_FILE" "$BACKUP_FILE.previous"
  chmod 600 "$BACKUP_FILE.previous"
fi

mv -f "$ENV_BACKUP_PENDING_FILE" "$BACKUP_FILE"
ENV_BACKUP_PENDING_FILE=""
chmod 600 "$BACKUP_FILE"

log "ENV BACKUP: Encrypted $FILE_COUNT file(s) → $BACKUP_FILE"
log "=== Env backup finished ==="
