#!/usr/bin/env bash
# =============================================================================
# iTerm2 Cobalt2 + Claude Code Setup Script
# =============================================================================
# Installs Oh My Zsh, Powerline fonts, Cobalt2 theme, and Claude Code
# prerequisites for multi-agent parallel development.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# After running, complete the manual iTerm2 steps in README.md:
#   1. Import juancamiloqhz-cobalt2.json profile
#   2. Set as default profile
#   3. Enable Python API in iTerm2 → Settings → General → Magic
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# ---- Homebrew ---------------------------------------------------------------
if ! command -v brew &>/dev/null; then
  error "Homebrew not found. Install it first: https://brew.sh"
  exit 1
fi
success "Homebrew found"

# ---- iTerm2 -----------------------------------------------------------------
if [ -d "/Applications/iTerm.app" ]; then
  success "iTerm2 found"
else
  info "Installing iTerm2..."
  brew install --cask iterm2
  success "iTerm2 installed"
fi

# ---- Oh My Zsh --------------------------------------------------------------
if [ -d "$HOME/.oh-my-zsh" ]; then
  success "Oh My Zsh already installed"
else
  info "Installing Oh My Zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed"
fi

# ---- Powerline Fonts --------------------------------------------------------
if fc-list 2>/dev/null | grep -qi "powerline" || system_profiler SPFontsDataType 2>/dev/null | grep -qi "Inconsolata.*Powerline"; then
  success "Powerline fonts already installed"
else
  info "Installing Powerline fonts..."
  git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
  cd /tmp/powerline-fonts
  ./install.sh
  cd "$SCRIPT_DIR"
  rm -rf /tmp/powerline-fonts
  success "Powerline fonts installed"
fi

# ---- Cobalt2 ZSH Theme ------------------------------------------------------
THEME_DEST="$HOME/.oh-my-zsh/themes/cobalt2.zsh-theme"
if [ -f "$THEME_DEST" ]; then
  success "Cobalt2 ZSH theme already installed"
else
  info "Installing Cobalt2 ZSH theme..."
  # Use local backup if available, otherwise download
  if [ -f "$SCRIPT_DIR/cobalt2.zsh-theme" ]; then
    cp "$SCRIPT_DIR/cobalt2.zsh-theme" "$THEME_DEST"
  else
    curl -fsSL -o "$THEME_DEST" \
      https://raw.githubusercontent.com/wesbos/Cobalt2-iterm/master/cobalt2.zsh-theme
  fi
  success "Cobalt2 ZSH theme installed"
fi

# ---- tmux (for Claude Code agent teams) -------------------------------------
if command -v tmux &>/dev/null; then
  success "tmux already installed ($(tmux -V))"
else
  info "Installing tmux..."
  brew install tmux
  success "tmux installed"
fi

# ---- it2 CLI (for Claude Code iTerm2 split panes) ---------------------------
if command -v it2 &>/dev/null; then
  success "it2 CLI already installed"
else
  info "Installing it2 CLI..."
  brew install mkusaka/tap/it2
  success "it2 CLI installed"
fi

# ---- Claude Code -------------------------------------------------------------
if command -v claude &>/dev/null; then
  success "Claude Code already installed ($(claude --version 2>/dev/null || echo 'installed'))"
else
  warn "Claude Code not found. Install it with: npm install -g @anthropic-ai/claude-code"
fi

# ---- Download Cobalt2 iTerm colors (backup) ----------------------------------
if [ ! -f "$SCRIPT_DIR/cobalt2.itermcolors" ]; then
  info "Downloading cobalt2.itermcolors as backup..."
  curl -fsSL -o "$SCRIPT_DIR/cobalt2.itermcolors" \
    https://raw.githubusercontent.com/wesbos/Cobalt2-iterm/master/cobalt2.itermcolors
  success "cobalt2.itermcolors downloaded"
fi

# ---- Backup Cobalt2 ZSH theme locally ---------------------------------------
if [ ! -f "$SCRIPT_DIR/cobalt2.zsh-theme" ]; then
  info "Saving local copy of cobalt2.zsh-theme..."
  cp "$THEME_DEST" "$SCRIPT_DIR/cobalt2.zsh-theme"
  success "cobalt2.zsh-theme backed up"
fi

# ---- Summary -----------------------------------------------------------------
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "  ${YELLOW}Manual steps remaining:${NC}"
echo ""
echo "  1. Open iTerm2 → Settings → Profiles"
echo "     → Other Actions... → Import JSON Profiles..."
echo "     → Select: $SCRIPT_DIR/juancamiloqhz-cobalt2.json"
echo "     → Other Actions... → Set as Default"
echo ""
echo "  2. iTerm2 → Settings → General → Magic"
echo "     → ✅ Enable Python API"
echo ""
echo "  3. Open a new iTerm2 tab (Cmd+T) to see the theme"
echo ""
echo -e "  ${BLUE}To start parallel Claude Code sessions:${NC}"
echo "     cd ~/project && claude --worktree feature-name"
echo ""