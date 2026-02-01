# dotfiles

Personal macOS configuration files and setup automation.

## What's included

| Path                                      | Description                                                                            |
| ----------------------------------------- | -------------------------------------------------------------------------------------- |
| `Brewfile`                                | Homebrew packages, casks, and Mac App Store apps                                       |
| `install.sh`                              | Setup script — installs Brewfile, creates symlinks, installs Cursor extensions         |
| `zsh/.zshrc`                              | Zsh shell configuration                                                                |
| `git/.gitconfig`                          | Git configuration                                                                      |
| `cursor/settings.json`                    | Cursor editor settings                                                                 |
| `cursor/keybindings.json`                 | Cursor keybindings                                                                     |
| `cursor/extensions.txt`                   | Cursor extension list                                                                  |
| `scripts/auto-backup.sh`                  | Daily auto-backup script (exports Brewfile + extensions + .env files, commits, pushes) |
| `scripts/env-backup.sh`                   | Encrypts all `.env` files from `~/Dev/` to iCloud Drive                                |
| `scripts/env-restore.sh`                  | Restores `.env` files from encrypted iCloud backup                                     |
| `com.juancamiloqhz.dotfiles-backup.plist` | macOS LaunchAgent that runs the backup script daily                                    |
| `crontab/README.md`                       | Crontab job documentation                                                              |

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

**Shell tokens** (e.g. `GITHUB_REGISTRY_TOKEN`) live in `~/.secrets`, which is sourced by `.zshrc` but never committed to git.

**Project `.env` files** are backed up automatically by `scripts/env-backup.sh`. It scans `~/Dev/` for all `.env*` files, encrypts them with `openssl aes-256-cbc`, and stores the archive in iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/Backups/env-backup.enc`).

```bash
# Manual backup
bash scripts/env-backup.sh

# Restore on a new machine (skips files that already exist)
bash scripts/env-restore.sh

# Restore and overwrite existing files
bash scripts/env-restore.sh --force
```

The passphrase is read from `ENV_BACKUP_PASSPHRASE` in `~/.secrets`. On restore, if not set, it will prompt interactively.

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
3. Encrypts all `.env` files from `~/Dev/` to iCloud Drive
4. Commits and pushes any changes to the remote

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
3. Add `ENV_BACKUP_PASSPHRASE="..."` to `~/.secrets`
4. Run `bash scripts/env-restore.sh` to restore all `.env` files
5. Generate SSH keys and add to GitHub
6. Set up crontab jobs (see `crontab/README.md`)
7. Sign into apps manually: 1Password, Cursor, Raycast, Slack, Figma
