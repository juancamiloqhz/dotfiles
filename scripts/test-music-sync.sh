#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync-music-library.sh"
TEST_ROOT="$(mktemp -d)"
TEST_CONFIG_DIR="$TEST_ROOT/config"
TEST_PLAYLIST_DIR="$TEST_CONFIG_DIR/playlists"
FIXTURE_DIR="$TEST_ROOT/pls"
YOUTUBE_FEED="$TEST_ROOT/productivity-fm.tsv"
MANAGED_MARKER="# Managed by dotfiles music sync. Do not edit."

cleanup() {
  rm -rf -- "$TEST_ROOT"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$FIXTURE_DIR"
for fixture_name in dronezone256.pls groovesalad256.pls deepspaceone.pls defcon256.pls; do
  stream_name="${fixture_name%.pls}"
  printf '[playlist]\nFile1=https://streams.example.test/%s.mp3\nNumberOfEntries=1\n' \
    "$stream_name" > "$FIXTURE_DIR/$fixture_name"
done

printf '%s\t%s\n' \
  'https://www.youtube.com/watch?v=fixture001' 'Productivity mix "one"' \
  'https://www.youtube.com/watch?v=fixture002' 'Productivity mix two' \
  > "$YOUTUBE_FEED"

run_sync() {
  CLIAMP_CONFIG_DIR="$TEST_CONFIG_DIR" \
  MUSIC_SYNC_PLS_FIXTURE_DIR="$FIXTURE_DIR" \
  MUSIC_SYNC_YOUTUBE_FEED_FILE="$YOUTUBE_FEED" \
    "$SYNC_SCRIPT"
}

run_sync >/dev/null

playlist_count="$(find "$TEST_PLAYLIST_DIR" -maxdepth 1 -name '*.toml' -type f | wc -l | tr -d ' ')"
[ "$playlist_count" -eq 11 ] || {
  printf 'expected 11 generated playlists, found %s\n' "$playlist_count" >&2
  exit 1
}

deep_playlist="$TEST_PLAYLIST_DIR/FOCUS · Deep.toml"
soma_playlist="$TEST_PLAYLIST_DIR/SOURCE · SomaFM.toml"
productivity_playlist="$TEST_PLAYLIST_DIR/SOURCE · Productivity FM.toml"

[ "$(sed -n '1p' "$deep_playlist")" = "$MANAGED_MARKER" ]
grep -q 'https://streams.example.test/dronezone256.mp3' "$deep_playlist"
[ "$(grep -c '^\[\[track\]\]$' "$soma_playlist")" -eq 4 ]
[ "$(grep -c '^\[\[track\]\]$' "$productivity_playlist")" -eq 2 ]
grep -q 'title = "Productivity mix \\"one\\""' "$productivity_playlist"

# A second run must be idempotent.
before_hash="$(find "$TEST_PLAYLIST_DIR" -type f -exec shasum {} + | sort | shasum | awk '{print $1}')"
run_sync >/dev/null
after_hash="$(find "$TEST_PLAYLIST_DIR" -type f -exec shasum {} + | sort | shasum | awk '{print $1}')"
[ "$before_hash" = "$after_hash" ] || {
  printf 'music sync is not idempotent\n' >&2
  exit 1
}

# Stale files listed in the managed manifest should be removed safely.
stale_playlist="$TEST_PLAYLIST_DIR/STALE · Managed.toml"
printf '%s\n' "$MANAGED_MARKER" > "$stale_playlist"
printf '%s\n' 'STALE · Managed.toml' >> "$TEST_PLAYLIST_DIR/.dotfiles-music-manifest"
run_sync >/dev/null
[ ! -e "$stale_playlist" ] || {
  printf 'stale managed playlist was not removed\n' >&2
  exit 1
}

# User-owned files must never be overwritten.
conflict_dir="$TEST_ROOT/conflict-playlists"
mkdir -p "$conflict_dir"
printf 'user playlist\n' > "$conflict_dir/FOCUS · Deep.toml"
if CLIAMP_PLAYLIST_DIR="$conflict_dir" \
  MUSIC_SYNC_PLS_FIXTURE_DIR="$FIXTURE_DIR" \
  MUSIC_SYNC_YOUTUBE_FEED_FILE="$YOUTUBE_FEED" \
  "$SYNC_SCRIPT" >/dev/null 2>&1; then
  printf 'music sync overwrote an unowned playlist\n' >&2
  exit 1
fi
grep -q '^user playlist$' "$conflict_dir/FOCUS · Deep.toml"

if command -v cliamp >/dev/null 2>&1; then
  cliamp_output="$(CLIAMP_CONFIG_DIR="$TEST_CONFIG_DIR" cliamp playlist list)"
  case "$cliamp_output" in
    *"FOCUS · Deep"*"SOURCE · Productivity FM"*) ;;
    *) printf 'CLIamp did not load the generated playlists\n' >&2; exit 1 ;;
  esac
fi

printf 'music library sync tests passed\n'
