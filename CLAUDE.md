# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

macOS dotfiles — config files, an install script, a Brewfile, and a daily auto-backup system. Everything is symlinked from this repo to its expected location on disk.

## Key commands

```bash
# Full setup (symlinks, brew, cursor extensions, LaunchAgent)
./install.sh

# Manual backup (same thing the LaunchAgent runs daily at noon)
bash scripts/auto-backup.sh

# Re-export after installing new brew packages
brew bundle dump --file=~/Dev/dotfiles/Brewfile --force

# Re-export after changing Cursor extensions
cursor --list-extensions > ~/Dev/dotfiles/cursor/extensions.txt

# Check LaunchAgent status
launchctl list | grep dotfiles

# View backup log
tail -20 ~/.local/share/dotfiles-backup/backup.log
```

## Architecture

- **`install.sh`** — idempotent setup script. Creates symlinks (backing up existing files), loads the LaunchAgent, runs `brew bundle`, and installs Cursor extensions. Safe to re-run.
- **`scripts/auto-backup.sh`** — run daily by the LaunchAgent. Re-exports Brewfile and Cursor extensions, runs env-backup, commits and pushes if anything changed. Guards against missing tools.
- **`scripts/env-backup.sh`** — finds all `.env*` files under `~/Dev/`, encrypts them into a single archive with openssl, stores it in iCloud Drive. Passphrase comes from `ENV_BACKUP_PASSPHRASE` in `~/.secrets`.
- **`scripts/env-restore.sh`** — decrypts the iCloud archive and restores `.env` files to `~/Dev/`. Skips existing files unless `--force` is passed.
- **`com.juancamiloqhz.dotfiles-backup.plist`** — macOS LaunchAgent definition. Gets symlinked into `~/Library/LaunchAgents/` by install.sh. Runs the backup script at noon; if asleep, runs on wake.

## Symlink mapping

| Repo path                                 | Symlinked to                                                 |
| ----------------------------------------- | ------------------------------------------------------------ |
| `zsh/.zshrc`                              | `~/.zshrc`                                                   |
| `git/.gitconfig`                          | `~/.gitconfig`                                               |
| `cursor/settings.json`                    | `~/Library/Application Support/Cursor/User/settings.json`    |
| `cursor/keybindings.json`                 | `~/Library/Application Support/Cursor/User/keybindings.json` |
| `com.juancamiloqhz.dotfiles-backup.plist` | `~/Library/LaunchAgents/`                                    |

## Secrets

Secrets are **not** stored in this repo. The `.zshrc` sources `~/.secrets` (a local-only file) for shell tokens. Project `.env` files are encrypted and backed up to iCloud Drive by `scripts/env-backup.sh`; the passphrase is `ENV_BACKUP_PASSPHRASE` in `~/.secrets`.

## Conventions

- Paths assume the repo lives at `~/Dev/dotfiles`. The plist and auto-backup script both hardcode this.
- Shell scripts use `set -euo pipefail`.
- `install.sh` uses a `link_file` helper that checks for existing symlinks before acting and backs up conflicts to `~/.dotfiles-backup/<timestamp>/`.
