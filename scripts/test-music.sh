#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MUSIC_BIN="$DOTFILES_DIR/bin/music"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

"$MUSIC_BIN" doctor >/dev/null

printf '%s\n' \
  $'focus\tFocus\tBroken test menu\tmenu\t-' \
  $'focus/deep\tDeep\tBroken alias\talias\tsource/missing' \
  > "$TEST_ROOT/invalid-catalog.tsv"

if MUSIC_CATALOG_FILE="$TEST_ROOT/invalid-catalog.tsv" \
  "$MUSIC_BIN" doctor >/dev/null 2>&1; then
  printf 'catalog doctor accepted an invalid alias\n' >&2
  exit 1
fi

deep_output="$(MUSIC_DRY_RUN=true "$MUSIC_BIN" focus deep)"
case "$deep_output" in
  *"https://somafm.com/dronezone256.pls"*) ;;
  *) printf 'deep focus route failed\n' >&2; exit 1 ;;
esac

library_output="$(MUSIC_DRY_RUN=true "$MUSIC_BIN" browse library)"
case "$library_output" in
  *"--provider ytmusic"*) ;;
  *) printf 'YouTube Music provider route failed\n' >&2; exit 1 ;;
esac

channel_output="$(MUSIC_DRY_RUN=true "$MUSIC_BIN" source productivity-fm)"
case "$channel_output" in
  *"https://www.youtube.com/@productivityonyt/videos"*) ;;
  *) printf 'Productivity FM route failed\n' >&2; exit 1 ;;
esac

catalog_output="$("$MUSIC_BIN" list)"
case "$catalog_output" in
  *"productivity-fm"*"drone-zone"*"library"*) ;;
  *) printf 'catalog listing is incomplete\n' >&2; exit 1 ;;
esac

ln -s "$MUSIC_BIN" "$TEST_ROOT/music"
symlink_output="$(MUSIC_DRY_RUN=true "$TEST_ROOT/music" focus flow)"
case "$symlink_output" in
  *"https://somafm.com/groovesalad256.pls"*) ;;
  *) printf 'symlink catalog resolution failed\n' >&2; exit 1 ;;
esac

interactive_output="$(printf '1\n1\n' | MUSIC_DRY_RUN=true "$MUSIC_BIN")"
case "$interactive_output" in
  *"https://somafm.com/dronezone256.pls"*) ;;
  *) printf 'interactive navigation failed\n' >&2; exit 1 ;;
esac

printf 'music launcher tests passed\n'
