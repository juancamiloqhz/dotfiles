# iTerm2 + Cobalt2

> One-command terminal setup for a new Mac. Cobalt2 theme, Oh My Zsh, Powerline fonts, word-navigation key mappings.

## Prerequisites

- macOS with [Homebrew](https://brew.sh/) installed
- [iTerm2](https://iterm2.com/) (installed automatically by the script if missing)

## Quick Install (Automated)

```bash
cd ~/Dev/dotfiles/iterm2  # or wherever you cloned this
chmod +x install.sh
./install.sh
```

Then complete the [manual iTerm2 steps](#manual-iterm2-steps) below.

## Manual Step-by-Step Install

### 1. Install Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 2. Install Powerline Fonts

```bash
git clone https://github.com/powerline/fonts.git --depth=1 /tmp/powerline-fonts
cd /tmp/powerline-fonts
./install.sh
rm -rf /tmp/powerline-fonts
```

### 3. Install Cobalt2 ZSH Theme

```bash
curl -o ~/.oh-my-zsh/themes/cobalt2.zsh-theme \
  https://raw.githubusercontent.com/wesbos/Cobalt2-iterm/master/cobalt2.zsh-theme
```

### 4. ZSH Theme

The `.zshrc` from this dotfiles repo already has `ZSH_THEME="cobalt2"` configured. No manual step needed if you ran the main `install.sh`.

### 5. Import iTerm2 Profile

This repo includes `juancamiloqhz-cobalt2.json` — a pre-configured iTerm2 profile with:

- Cobalt2 color scheme
- Menlo Regular font (size 15)
- Word-navigation key mappings (Option+Arrow, Cmd+Arrow, etc.)
- Powerline glyphs enabled

**Import it:**

1. Open **iTerm2 → Settings → Profiles**
2. Click **Other Actions... → Import JSON Profiles...**
3. Select `juancamiloqhz-cobalt2.json` from this directory
4. Click **Other Actions... → Set as Default**

### 6. Claude Code Prerequisites (for Agent Teams with split panes)

```bash
# Install tmux
brew install tmux

# Install it2 CLI (iTerm2 Python API bridge for Claude Code agent teams)
brew install mkusaka/tap/it2
```

Then in **iTerm2 → Settings → General → Magic**:

- ✅ Enable **Python API**

### 7. Reload

```bash
source ~/.zshrc
```

Open a new tab (Cmd+T) to see the full Cobalt2 prompt.

---

## Manual iTerm2 Steps

These settings are included in the JSON profile, but if importing doesn't work or you're setting up from scratch:

### Colors

1. Download: `curl -o ~/Downloads/cobalt2.itermcolors https://raw.githubusercontent.com/wesbos/Cobalt2-iterm/master/cobalt2.itermcolors`
2. **Profiles → Colors → Color Presets... → Import...** → select the file
3. **Color Presets... → cobalt2**

### Font

1. **Profiles → Text** → set font to **Menlo Regular**, size 15
2. ✅ Check **Use built-in Powerline glyphs**

### Key Mappings (word navigation)

Go to **Profiles → Keys → Key Mappings**, click **+** for each:

| Shortcut        | Action               | Value  |
| --------------- | -------------------- | ------ |
| ⌥←              | Send Escape Sequence | `b`    |
| ⌥→              | Send Escape Sequence | `f`    |
| ⌥⌫ (Opt+Delete) | Send Hex Code        | `0x17` |
| ⌘←              | Send Hex Code        | `0x01` |
| ⌘→              | Send Hex Code        | `0x05` |
| ⌘⌫ (Cmd+Delete) | Send Hex Code        | `0x15` |

---

## File Structure

```
iterm2/
├── README.md                       # This file
├── install.sh                      # Automated installer script
└── juancamiloqhz-cobalt2.json     # iTerm2 profile (colors + fonts + keys)
```

---

## Updating

To re-export your profile after making changes:

1. **iTerm2 → Settings → Profiles → Other Actions... → Export JSON Profile...**
2. Save as `juancamiloqhz-cobalt2.json` in this directory
3. Commit to dotfiles repo

---

## Credits

- [Cobalt2 by Wes Bos](https://github.com/wesbos/Cobalt2-iterm)
- [Oh My Zsh](https://ohmyz.sh/)
- [Powerline Fonts](https://github.com/powerline/fonts)
