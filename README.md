# dotfiles

Personal macOS configuration files and setup automation.

## What's included

| Path | Description |
| --- | --- |
| `Brewfile` | Homebrew packages, casks, and Mac App Store apps |
| `install.sh` | Setup script — installs Brewfile, creates symlinks, installs Cursor extensions |
| `zsh/.zshrc` | Zsh shell configuration |
| `git/.gitconfig` | Git configuration |
| `cursor/settings.json` | Cursor editor settings |
| `cursor/keybindings.json` | Cursor keybindings |
| `cursor/extensions.txt` | Cursor extension list |
| `scripts/auto-backup.sh` | Daily auto-backup script (exports Brewfile + extensions, commits, pushes) |
| `com.juancamiloqhz.dotfiles-backup.plist` | macOS LaunchAgent that runs the backup script daily |
| `crontab/README.md` | Crontab job documentation |

## Install (new machine)

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Clone and run
git clone https://github.com/juancamiloqhz/dotfiles.git ~/dotfiles
cd ~/dotfiles && chmod +x install.sh && ./install.sh
```

`install.sh` backs up existing configs, creates symlinks, installs Brewfile packages, and installs Cursor extensions.

## Secrets management

Secrets are managed with [Doppler](https://doppler.com), not this repo.

```bash
brew install dopplerhq/cli/doppler
doppler login

# Per project
cd ~/projects/my-app
doppler setup
doppler run -- npm run dev
```

## SSH keys

Generated fresh per machine (not backed up).

```bash
ssh-keygen -t ed25519 -C "juancamiloqhz@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
# Add at https://github.com/settings/keys
```

## Maintenance

```bash
# After installing new apps
brew bundle dump --file=~/dotfiles/Brewfile --force

# After changing Cursor extensions
cursor --list-extensions > ~/dotfiles/cursor/extensions.txt

# After changing shell config — already symlinked, just commit
cd ~/dotfiles && git add -A && git commit -m "update configs" && git push
```

## Auto-backup

A LaunchAgent runs `scripts/auto-backup.sh` daily at 12:00 noon. If the machine is asleep, macOS runs it on the next wake.

**What it does:**

1. Re-exports `Brewfile` via `brew bundle dump`
2. Re-exports Cursor extensions to `cursor/extensions.txt`
3. Commits and pushes any changes to the remote

**Logs:** `~/.local/share/dotfiles-backup/backup.log`

**Check status:**

```bash
launchctl list | grep dotfiles
tail -20 ~/.local/share/dotfiles-backup/backup.log
```

**Disable/enable:**

```bash
launchctl unload ~/Library/LaunchAgents/com.juancamiloqhz.dotfiles-backup.plist
launchctl load   ~/Library/LaunchAgents/com.juancamiloqhz.dotfiles-backup.plist
```

## New machine checklist

1. Install Homebrew
2. Clone repo and run `./install.sh`
3. `doppler login`
4. Generate SSH keys and add to GitHub
5. Set up crontab jobs (see `crontab/README.md`)
6. Sign into apps manually: 1Password, Cursor, Raycast, Slack, Figma
