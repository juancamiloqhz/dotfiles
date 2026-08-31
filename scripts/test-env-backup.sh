#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

SOURCE_DIR="$TEST_ROOT/source"
RESTORE_DIR="$TEST_ROOT/restored"
BACKUP_FILE="$TEST_ROOT/backups/env-backup.enc"
TEST_LOG="$TEST_ROOT/backup.log"

mkdir -p "$SOURCE_DIR/project/node_modules/package"
printf 'API_KEY=round-trip-test\n' > "$SOURCE_DIR/project/.env"
printf 'DEPLOYMENT=production\n' > "$SOURCE_DIR/project/.env.production"
printf 'SHOULD_NOT_BACK_UP=true\n' > "$SOURCE_DIR/project/node_modules/package/.env"

DOTFILES_DEV_DIR="$SOURCE_DIR" \
DOTFILES_ENV_BACKUP_FILE="$BACKUP_FILE" \
DOTFILES_SECRETS_FILE=/dev/null \
DOTFILES_BACKUP_LOG_FILE="$TEST_LOG" \
ENV_BACKUP_PASSPHRASE='dotfiles-test-passphrase' \
  bash "$SCRIPT_DIR/env-backup.sh"

test -s "$BACKUP_FILE"
test "$(stat -f '%Lp' "$BACKUP_FILE")" = "600"

DOTFILES_DEV_DIR="$RESTORE_DIR" \
DOTFILES_ENV_BACKUP_FILE="$BACKUP_FILE" \
DOTFILES_SECRETS_FILE=/dev/null \
ENV_BACKUP_PASSPHRASE='dotfiles-test-passphrase' \
  bash "$SCRIPT_DIR/env-restore.sh"

cmp "$SOURCE_DIR/project/.env" "$RESTORE_DIR/project/.env"
cmp "$SOURCE_DIR/project/.env.production" "$RESTORE_DIR/project/.env.production"
test ! -e "$RESTORE_DIR/project/node_modules/package/.env"

# A second successful backup must preserve the first encrypted generation.
printf 'API_KEY=second-generation\n' > "$SOURCE_DIR/project/.env"
DOTFILES_DEV_DIR="$SOURCE_DIR" \
DOTFILES_ENV_BACKUP_FILE="$BACKUP_FILE" \
DOTFILES_SECRETS_FILE=/dev/null \
DOTFILES_BACKUP_LOG_FILE="$TEST_LOG" \
ENV_BACKUP_PASSPHRASE='dotfiles-test-passphrase' \
  bash "$SCRIPT_DIR/env-backup.sh"

test -s "$BACKUP_FILE.previous"
test "$(stat -f '%Lp' "$BACKUP_FILE.previous")" = "600"

printf 'env backup/restore round-trip passed\n'
