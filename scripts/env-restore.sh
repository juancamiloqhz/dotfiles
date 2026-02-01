#!/usr/bin/env bash
set -euo pipefail

DEV_DIR="$HOME/Dev"
BACKUP_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups"
BACKUP_FILE="$BACKUP_DIR/env-backup.enc"
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: No backup found at $BACKUP_FILE"
  echo "Make sure iCloud Drive is synced."
  exit 1
fi

# Get passphrase — from ~/.secrets or prompt
if [ -f "$HOME/.secrets" ]; then
  source "$HOME/.secrets"
fi

if [ -z "${ENV_BACKUP_PASSPHRASE:-}" ]; then
  read -rsp "Enter env backup passphrase: " ENV_BACKUP_PASSPHRASE
  echo
fi

TMPDIR_RESTORE="$(mktemp -d)"

# Decrypt
if ! openssl enc -aes-256-cbc -d -salt -pbkdf2 \
  -in "$BACKUP_FILE" \
  -out "$TMPDIR_RESTORE/env-archive.tar" \
  -pass pass:"$ENV_BACKUP_PASSPHRASE" 2>/dev/null; then
  echo "ERROR: Decryption failed. Wrong passphrase?"
  rm -rf "$TMPDIR_RESTORE"
  exit 1
fi

# List files in archive
FILE_LIST=$(tar -tf "$TMPDIR_RESTORE/env-archive.tar")
FILE_COUNT=$(echo "$FILE_LIST" | wc -l | tr -d ' ')

echo "Found $FILE_COUNT .env file(s) in backup:"
echo ""

# Check for conflicts
CONFLICTS=0
while IFS= read -r file; do
  dst="$DEV_DIR/$file"
  if [ -f "$dst" ] && [ "$FORCE" = false ]; then
    echo "  SKIP (exists): $file"
    CONFLICTS=$((CONFLICTS + 1))
  else
    echo "  RESTORE: $file"
  fi
done <<< "$FILE_LIST"

if [ "$CONFLICTS" -gt 0 ] && [ "$FORCE" = false ]; then
  echo ""
  echo "$CONFLICTS file(s) skipped (already exist). Use --force to overwrite."
fi

# Extract
if [ "$FORCE" = true ]; then
  tar -xf "$TMPDIR_RESTORE/env-archive.tar" -C "$DEV_DIR"
  echo ""
  echo "Restored all $FILE_COUNT file(s) to $DEV_DIR/"
else
  # Extract to temp, then copy only missing files
  tar -xf "$TMPDIR_RESTORE/env-archive.tar" -C "$TMPDIR_RESTORE/extracted" 2>/dev/null \
    || (mkdir -p "$TMPDIR_RESTORE/extracted" && tar -xf "$TMPDIR_RESTORE/env-archive.tar" -C "$TMPDIR_RESTORE/extracted")

  RESTORED=0
  while IFS= read -r file; do
    dst="$DEV_DIR/$file"
    src="$TMPDIR_RESTORE/extracted/$file"
    if [ ! -f "$dst" ]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      RESTORED=$((RESTORED + 1))
    fi
  done <<< "$FILE_LIST"
  echo ""
  echo "Restored $RESTORED new file(s) to $DEV_DIR/"
fi

rm -rf "$TMPDIR_RESTORE"
