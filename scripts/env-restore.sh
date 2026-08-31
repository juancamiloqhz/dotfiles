#!/usr/bin/env bash
set -euo pipefail

DEV_DIR="${DOTFILES_DEV_DIR:-$HOME/Dev}"
BACKUP_FILE="${DOTFILES_ENV_BACKUP_FILE:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Backups/env-backup.enc}"
SECRETS_FILE="${DOTFILES_SECRETS_FILE:-$HOME/.secrets}"
ENV_RESTORE_TEMP_DIR=""
FORCE=false

umask 077

cleanup() {
  if [ -n "$ENV_RESTORE_TEMP_DIR" ] && [ -d "$ENV_RESTORE_TEMP_DIR" ]; then
    rm -rf -- "$ENV_RESTORE_TEMP_DIR"
  fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

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

# Get passphrase — from the machine-local secrets file or prompt.
if [ -f "$SECRETS_FILE" ]; then
  source "$SECRETS_FILE"
fi

if [ -z "${ENV_BACKUP_PASSPHRASE:-}" ]; then
  read -rsp "Enter env backup passphrase: " ENV_BACKUP_PASSPHRASE
  echo
fi

export ENV_BACKUP_PASSPHRASE
ENV_RESTORE_TEMP_DIR="$(mktemp -d)"

# Decrypt
if ! openssl enc -aes-256-cbc -d -salt -pbkdf2 \
  -in "$BACKUP_FILE" \
  -out "$ENV_RESTORE_TEMP_DIR/env-archive.tar" \
  -pass env:ENV_BACKUP_PASSPHRASE 2>/dev/null; then
  echo "ERROR: Decryption failed. Wrong passphrase?"
  exit 1
fi

# List files in archive
FILE_LIST=$(tar -tf "$ENV_RESTORE_TEMP_DIR/env-archive.tar")
FILE_COUNT=$(echo "$FILE_LIST" | wc -l | tr -d ' ')

# Reject archive paths that could escape ~/Dev before extracting anything.
while IFS= read -r file; do
  case "$file" in
    ""|/*|..|../*|*/../*|*/..)
      echo "ERROR: Unsafe path in backup archive: $file" >&2
      exit 1
      ;;
  esac
done <<< "$FILE_LIST"

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
mkdir -p "$DEV_DIR"
if [ "$FORCE" = true ]; then
  tar -xf "$ENV_RESTORE_TEMP_DIR/env-archive.tar" -C "$DEV_DIR"
  echo ""
  echo "Restored all $FILE_COUNT file(s) to $DEV_DIR/"
else
  # Extract to temp, then copy only missing files
  mkdir -p "$ENV_RESTORE_TEMP_DIR/extracted"
  tar -xf "$ENV_RESTORE_TEMP_DIR/env-archive.tar" -C "$ENV_RESTORE_TEMP_DIR/extracted"

  RESTORED=0
  while IFS= read -r file; do
    dst="$DEV_DIR/$file"
    src="$ENV_RESTORE_TEMP_DIR/extracted/$file"
    if [ ! -f "$dst" ]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      RESTORED=$((RESTORED + 1))
    fi
  done <<< "$FILE_LIST"
  echo ""
  echo "Restored $RESTORED new file(s) to $DEV_DIR/"
fi
