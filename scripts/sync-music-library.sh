#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CATALOG_FILE="${MUSIC_CATALOG_FILE:-$DOTFILES_DIR/music/catalog.tsv}"
CLIAMP_CONFIG_DIR="${CLIAMP_CONFIG_DIR:-$HOME/.config/cliamp}"
PLAYLIST_DIR="${CLIAMP_PLAYLIST_DIR:-$CLIAMP_CONFIG_DIR/playlists}"
YTDLP_BIN="${MUSIC_YTDLP_BIN:-yt-dlp}"
CURL_BIN="${MUSIC_CURL_BIN:-curl}"
YOUTUBE_LIMIT="${MUSIC_YOUTUBE_LIMIT:-10}"
PLS_FIXTURE_DIR="${MUSIC_SYNC_PLS_FIXTURE_DIR:-}"
YOUTUBE_FEED_FILE="${MUSIC_SYNC_YOUTUBE_FEED_FILE:-}"
MANAGED_MARKER="# Managed by dotfiles music sync. Do not edit."
MANIFEST_NAME=".dotfiles-music-manifest"
SYNC_TEMP_DIR="$(mktemp -d)"
BUILD_DIR="$SYNC_TEMP_DIR/playlists"
REMOTE_CACHE_DIR="$SYNC_TEMP_DIR/remote-cache"
SYNC_PENDING_FILE=""

cleanup() {
  if [ -n "$SYNC_PENDING_FILE" ] && [ -e "$SYNC_PENDING_FILE" ]; then
    rm -f -- "$SYNC_PENDING_FILE"
  fi
  if [ -d "$SYNC_TEMP_DIR" ]; then
    rm -rf -- "$SYNC_TEMP_DIR"
  fi
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  printf 'music sync: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$BUILD_DIR" "$REMOTE_CACHE_DIR"

MUSIC_CATALOG_FILE="$CATALOG_FILE" "$DOTFILES_DIR/bin/music" doctor >/dev/null

case "$YOUTUBE_LIMIT" in
  ''|*[!0-9]*) fail "MUSIC_YOUTUBE_LIMIT must be a positive integer" ;;
  0) fail "MUSIC_YOUTUBE_LIMIT must be greater than zero" ;;
esac

NODE_PATH=""
NODE_LABEL=""
NODE_DESCRIPTION=""
NODE_ACTION=""
NODE_TARGET=""

load_node() {
  local wanted_path="$1"
  local path label description action target

  while IFS=$'\t' read -r path label description action target; do
    case "$path" in
      ""|\#*) continue ;;
    esac

    if [ "$path" = "$wanted_path" ]; then
      NODE_PATH="$path"
      NODE_LABEL="$label"
      NODE_DESCRIPTION="$description"
      NODE_ACTION="$action"
      NODE_TARGET="$target"
      return 0
    fi
  done < "$CATALOG_FILE"

  return 1
}

safe_filename() {
  local value="$1"
  value="${value//\//-}"
  value="${value//:/-}"
  printf '%s\n' "$value"
}

toml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/ }"
  value="${value//$'\r'/ }"
  value="${value//$'\t'/ }"
  printf '%s' "$value"
}

playlist_begin() {
  local category="$1"
  local label="$2"
  local safe_label playlist_name

  safe_label="$(safe_filename "$label")"
  playlist_name="$category · $safe_label.toml"
  CURRENT_PLAYLIST_FILE="$BUILD_DIR/$playlist_name"

  if [ -e "$CURRENT_PLAYLIST_FILE" ]; then
    fail "duplicate generated playlist name: $playlist_name"
  fi

  printf '%s\n' "$MANAGED_MARKER" > "$CURRENT_PLAYLIST_FILE"
  printf '# Generated from music/catalog.tsv. Run: music sync\n' >> "$CURRENT_PLAYLIST_FILE"
  DESIRED_PLAYLISTS+=("$playlist_name")
}

playlist_add_track() {
  local playlist_file="$1"
  local path="$2"
  local title="$3"
  local artist="$4"
  local genre="$5"
  local behavior="$6"

  {
    printf '\n[[track]]\n'
    printf 'path = "%s"\n' "$(toml_escape "$path")"
    printf 'title = "%s"\n' "$(toml_escape "$title")"
    printf 'artist = "%s"\n' "$(toml_escape "$artist")"
    printf 'genre = "%s"\n' "$(toml_escape "$genre")"
    case "$behavior" in
      feed) printf 'feed = true\n' ;;
      realtime) printf 'realtime = true\n' ;;
      finite) ;;
      *) fail "unknown track behavior: $behavior" ;;
    esac
  } >> "$playlist_file"
}

source_artist() {
  local source_path="$1"
  local remainder source_root

  remainder="${source_path#source/}"
  source_root="source/${remainder%%/*}"
  load_node "$source_root" || fail "source root not found: $source_root"
  printf '%s\n' "$NODE_LABEL"
}

fetch_pls() {
  local url="$1"
  local url_path fixture_name cache_file

  url_path="${url%%\?*}"
  fixture_name="${url_path##*/}"
  cache_file="$REMOTE_CACHE_DIR/$fixture_name"

  if [ ! -s "$cache_file" ]; then
    if [ -n "$PLS_FIXTURE_DIR" ]; then
      [ -f "$PLS_FIXTURE_DIR/$fixture_name" ] || fail "missing PLS fixture: $fixture_name"
      cp "$PLS_FIXTURE_DIR/$fixture_name" "$cache_file"
    else
      command -v "$CURL_BIN" >/dev/null 2>&1 || fail "curl is required to resolve PLS sources"
      "$CURL_BIN" --fail --silent --show-error --location --max-time 20 \
        "$url" > "$cache_file"
    fi
  fi

  printf '%s\n' "$cache_file"
}

resolve_pls_stream() {
  local url="$1"
  local pls_file resolved_url

  pls_file="$(fetch_pls "$url")"
  resolved_url="$(awk '
    tolower($0) ~ /^file[0-9]+=/ {
      value = $0
      sub(/^[^=]+=/, "", value)
      sub(/\r$/, "", value)
      print value
      exit
    }
  ' "$pls_file")"

  [ -n "$resolved_url" ] || fail "PLS source contains no stream URL: $url"
  printf '%s\n' "$resolved_url"
}

add_catalog_track() {
  local playlist_file="$1"
  local source_path="$2"
  local genre="$3"
  local artist resolved_path behavior

  load_node "$source_path" || fail "catalog source not found: $source_path"
  [ "$NODE_ACTION" = url ] || fail "catalog node is not a URL source: $source_path"

  artist="$(source_artist "$source_path")"
  load_node "$source_path" || fail "catalog source not found after artist lookup: $source_path"
  resolved_path="$NODE_TARGET"
  behavior="realtime"

  case "$resolved_path" in
    *.pls|*.pls\?*) resolved_path="$(resolve_pls_stream "$resolved_path")" ;;
    *.xml|*.xml\?*|*.rss|*.rss\?*|*.atom|*.atom\?*) behavior="feed" ;;
    *youtube.com/*|*youtu.be/*) behavior="finite" ;;
  esac

  playlist_add_track \
    "$playlist_file" \
    "$resolved_path" \
    "$NODE_LABEL" \
    "$artist" \
    "$genre" \
    "$behavior"
}

fetch_youtube_channel() {
  local channel_url="$1"
  local destination="$2"

  if [ -n "$YOUTUBE_FEED_FILE" ]; then
    [ -f "$YOUTUBE_FEED_FILE" ] || fail "YouTube feed fixture not found: $YOUTUBE_FEED_FILE"
    cp "$YOUTUBE_FEED_FILE" "$destination"
    return
  fi

  command -v "$YTDLP_BIN" >/dev/null 2>&1 || fail "yt-dlp is required to synchronize YouTube sources"
  "$YTDLP_BIN" \
    --flat-playlist \
    --playlist-end "$YOUTUBE_LIMIT" \
    --print $'%(webpage_url)s\t%(title)s' \
    "$channel_url" > "$destination"
}

add_youtube_channel_tracks() {
  local playlist_file="$1"
  local source_path="$2"
  local feed_file video_url video_title

  load_node "$source_path" || fail "YouTube source not found: $source_path"
  [ "$NODE_ACTION" = youtube-channel ] || fail "catalog node is not a YouTube channel: $source_path"
  feed_file="$REMOTE_CACHE_DIR/youtube-${source_path##*/}.tsv"
  fetch_youtube_channel "$NODE_TARGET" "$feed_file"

  while IFS=$'\t' read -r video_url video_title; do
    [ -n "$video_url" ] || continue
    playlist_add_track \
      "$playlist_file" \
      "$video_url" \
      "$video_title" \
      "$NODE_LABEL" \
      "Source · $NODE_LABEL" \
      finite
  done < "$feed_file"

  grep -q '^\[\[track\]\]$' "$playlist_file" || fail "YouTube source returned no videos: $source_path"
}

DESIRED_PLAYLISTS=()
CURRENT_PLAYLIST_FILE=""

# One native playlist per focus intent. Aliases keep source URLs canonical.
while IFS=$'\t' read -r focus_path focus_label focus_description focus_action focus_target; do
  case "$focus_path" in
    focus/*/*|""|\#*) continue ;;
    focus/*) ;;
    *) continue ;;
  esac

  [ "$focus_action" = alias ] || fail "focus entry must be an alias: $focus_path"
  playlist_begin FOCUS "$focus_label"
  add_catalog_track "$CURRENT_PLAYLIST_FILE" "$focus_target" "Focus · $focus_label"
done < "$CATALOG_FILE"

# One native playlist per top-level source. Menu sources collect all descendants.
while IFS=$'\t' read -r source_path source_label source_description source_action source_target; do
  case "$source_path" in
    source/*/*|""|\#*) continue ;;
    source/*) ;;
    *) continue ;;
  esac

  playlist_begin SOURCE "$source_label"

  case "$source_action" in
    url)
      add_catalog_track "$CURRENT_PLAYLIST_FILE" "$source_path" "Source · $source_label"
      ;;
    youtube-channel)
      add_youtube_channel_tracks "$CURRENT_PLAYLIST_FILE" "$source_path"
      ;;
    menu)
      while IFS=$'\t' read -r child_path child_label child_description child_action child_target; do
        case "$child_path" in
          "$source_path"/*)
            if [ "$child_action" = url ]; then
              add_catalog_track "$CURRENT_PLAYLIST_FILE" "$child_path" "Source · $source_label"
            elif [ "$child_action" = youtube-channel ]; then
              add_youtube_channel_tracks "$CURRENT_PLAYLIST_FILE" "$child_path"
            fi
            ;;
        esac
      done < "$CATALOG_FILE"
      ;;
    *) fail "unsupported top-level source action: $source_action" ;;
  esac
done < "$CATALOG_FILE"

[ "${#DESIRED_PLAYLISTS[@]}" -gt 0 ] || fail "catalog generated no playlists"

mkdir -p "$PLAYLIST_DIR"

# Refuse to overwrite user-owned playlists with a generated name.
for playlist_name in "${DESIRED_PLAYLISTS[@]}"; do
  destination="$PLAYLIST_DIR/$playlist_name"
  if [ -L "$destination" ]; then
    fail "refusing to replace symlink: $destination"
  fi
  if [ -e "$destination" ]; then
    IFS= read -r first_line < "$destination" || true
    [ "$first_line" = "$MANAGED_MARKER" ] || \
      fail "refusing to overwrite unowned playlist: $destination"
  fi
done

manifest_file="$PLAYLIST_DIR/$MANIFEST_NAME"
if [ -L "$manifest_file" ]; then
  fail "refusing to replace symlink: $manifest_file"
fi
if [ -e "$manifest_file" ]; then
  IFS= read -r first_line < "$manifest_file" || true
  [ "$first_line" = "$MANAGED_MARKER" ] || \
    fail "refusing to overwrite unowned manifest: $manifest_file"
fi

# Capture stale managed files before replacing the manifest.
STALE_PLAYLISTS=()
if [ -f "$manifest_file" ]; then
  while IFS= read -r old_playlist; do
    [ -n "$old_playlist" ] || continue
    [ "$old_playlist" = "$MANAGED_MARKER" ] && continue
    case "$old_playlist" in
      *.toml) ;;
      *) fail "unsafe playlist name in manifest: $old_playlist" ;;
    esac

    found=false
    for playlist_name in "${DESIRED_PLAYLISTS[@]}"; do
      if [ "$playlist_name" = "$old_playlist" ]; then
        found=true
        break
      fi
    done
    [ "$found" = true ] || STALE_PLAYLISTS+=("$old_playlist")
  done < "$manifest_file"
fi

# Publish each file atomically inside the CLIamp playlist directory.
for playlist_name in "${DESIRED_PLAYLISTS[@]}"; do
  source_file="$BUILD_DIR/$playlist_name"
  destination="$PLAYLIST_DIR/$playlist_name"
  SYNC_PENDING_FILE="$PLAYLIST_DIR/.music-sync.$$.tmp"
  cp "$source_file" "$SYNC_PENDING_FILE"
  chmod 644 "$SYNC_PENDING_FILE"
  mv -f "$SYNC_PENDING_FILE" "$destination"
  SYNC_PENDING_FILE=""
done

if [ "${#STALE_PLAYLISTS[@]}" -gt 0 ]; then
  for old_playlist in "${STALE_PLAYLISTS[@]}"; do
    stale_file="$PLAYLIST_DIR/$old_playlist"
    if [ -f "$stale_file" ]; then
      IFS= read -r first_line < "$stale_file" || true
      if [ "$first_line" = "$MANAGED_MARKER" ]; then
        rm "$stale_file"
      else
        printf 'music sync: kept unowned stale file: %s\n' "$stale_file" >&2
      fi
    fi
  done
fi

SYNC_PENDING_FILE="$PLAYLIST_DIR/.music-manifest.$$.tmp"
{
  printf '%s\n' "$MANAGED_MARKER"
  printf '%s\n' "${DESIRED_PLAYLISTS[@]}"
} > "$SYNC_PENDING_FILE"
chmod 644 "$SYNC_PENDING_FILE"
mv -f "$SYNC_PENDING_FILE" "$manifest_file"
SYNC_PENDING_FILE=""

printf 'Synced %d CLIamp playlists to %s\n' "${#DESIRED_PLAYLISTS[@]}" "$PLAYLIST_DIR"
