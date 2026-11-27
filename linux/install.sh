#!/usr/bin/env bash
# Linux (Arch/Omarchy) setup: installs packages and links scripts into ~/.local/bin.
# Usage: ./linux/install.sh [--links-only]
set -euo pipefail

LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
BIN_DIR="$HOME/.local/bin"

info()  { printf '  [ \033[0;34m..\033[0m ] %s\n' "$1"; }
ok()    { printf '  [ \033[0;32mOK\033[0m ] %s\n' "$1"; }
warn()  { printf '  [ \033[0;33m!!\033[0m ] %s\n' "$1"; }

link_file() {
  local src="$1" dst="$2"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "Already linked: $dst"
    return
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/"
    warn "Backed up existing $dst → $BACKUP_DIR/"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "Linked $src → $dst"
}

links_only=false
case "${1:-}" in
  "") ;;
  --links-only) links_only=true ;;
  *) echo "usage: $0 [--links-only]" >&2; exit 2 ;;
esac

if [ "$links_only" = false ]; then
  info "Installing packages..."
  if command -v pacman >/dev/null 2>&1; then
    mapfile -t packages < <(grep -v -E '^\s*(#|$)' "$LINUX_DIR/packages.txt")
    sudo pacman -S --needed "${packages[@]}"
  else
    warn "pacman not found; skipping packages (see linux/packages.txt)"
  fi
fi

info "Linking scripts into $BIN_DIR..."
for script in "$LINUX_DIR"/bin/*; do
  link_file "$script" "$BIN_DIR/$(basename "$script")"
done

ok "Done"
