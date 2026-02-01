#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info()  { printf '  [ \033[0;34m..\033[0m ] %s\n' "$1"; }
ok()    { printf '  [ \033[0;32mOK\033[0m ] %s\n' "$1"; }
warn()  { printf '  [ \033[0;33m!!\033[0m ] %s\n' "$1"; }
fail()  { printf '  [\033[0;31mFAIL\033[0m] %s\n' "$1"; }

link_file() {
  local src="$1" dst="$2"

  # Already pointing to the right place — skip
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "Already linked: $dst"
    return
  fi

  # Back up existing file/symlink
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$dst" "$BACKUP_DIR/"
    warn "Backed up existing $dst → $BACKUP_DIR/"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "Linked $src → $dst"
}

# ---------------------------------------------------------------------------
# Symlinks
# ---------------------------------------------------------------------------

info "Creating symlinks..."

link_file "$DOTFILES_DIR/zsh/.zshrc"            "$HOME/.zshrc"
link_file "$DOTFILES_DIR/git/.gitconfig"         "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/cursor/settings.json"   "$HOME/Library/Application Support/Cursor/User/settings.json"
link_file "$DOTFILES_DIR/cursor/keybindings.json" "$HOME/Library/Application Support/Cursor/User/keybindings.json"

# ---------------------------------------------------------------------------
# LaunchAgent (auto-backup)
# ---------------------------------------------------------------------------

PLIST_NAME="com.juancamiloqhz.dotfiles-backup.plist"
PLIST_SRC="$DOTFILES_DIR/$PLIST_NAME"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME"

link_file "$PLIST_SRC" "$PLIST_DST"

if launchctl list | grep -q "com.juancamiloqhz.dotfiles-backup"; then
  ok "LaunchAgent already loaded"
else
  launchctl load "$PLIST_DST" 2>/dev/null && ok "LaunchAgent loaded" || warn "Failed to load LaunchAgent"
fi

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

if command -v brew &>/dev/null; then
  info "Running brew bundle..."
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  ok "Homebrew packages installed"
else
  warn "brew not found — skipping Homebrew bundle"
fi

# ---------------------------------------------------------------------------
# Cursor extensions
# ---------------------------------------------------------------------------

if command -v cursor &>/dev/null; then
  info "Installing Cursor extensions..."
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    cursor --install-extension "$ext" --force 2>/dev/null || warn "Failed to install $ext"
  done < "$DOTFILES_DIR/cursor/extensions.txt"
  ok "Cursor extensions installed"
else
  warn "cursor CLI not found — skipping extension install"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo ""
ok "Dotfiles installed successfully!"
if [ -d "$BACKUP_DIR" ]; then
  info "Backups saved to $BACKUP_DIR"
fi
