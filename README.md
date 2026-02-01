# Machine Configuration & Backup Strategy

> My personal system configuration and the documentation for my complete backup/restore strategy.

When my MacBook got water damaged in early 2025, I lost everything — Cursor settings, crontabs, .env files across dozens of projects. This repo exists so that never happens again.

## Philosophy

My backup strategy separates concerns into **four layers**:

| Layer        | What                                      | Solution                       | Why                                                                            |
| ------------ | ----------------------------------------- | ------------------------------ | ------------------------------------------------------------------------------ |
| **Secrets**  | API keys, database URLs, .env files       | [Doppler](https://doppler.com) | Secrets should never touch git. Cloud-synced, team-shareable, pulls on demand. |
| **Configs**  | Editor settings, shell config, git config | This repo + symlinks           | Text files that rarely change. Version controlled.                             |
| **Apps**     | Installed applications                    | Brewfile                       | One command restores all apps.                                                 |
| **Crontabs** | Scheduled jobs                            | This repo (documented)         | Recreate manually from documentation.                                          |

**What's NOT in this system:**

- SSH keys → Generate fresh per machine (more secure)
- Browser profiles → Too large, use browser's built-in sync
- App data/caches → Not worth tracking
- License keys → Stored in 1Password

---

## 1. Secrets Management with Doppler

### Why Doppler over .env files?

- `.env` files get lost (they're gitignored)
- Sharing secrets with team members via Slack/email is insecure
- Managing secrets across dev/staging/prod is painful
- **Doppler solves all of this**

### Initial Setup (one time)

```bash
# Install Doppler CLI
brew install dopplerhq/cli/doppler

# Login to your account
doppler login
```

### Per-Project Setup

```bash
# Navigate to your project
cd ~/projects/casecam

# Link this folder to a Doppler project
doppler setup
# Select: project → environment (dev/staging/prod)

# Verify it works
doppler secrets
```

### Daily Usage

Instead of relying on a `.env` file, run your dev server through Doppler:

```bash
# Instead of: npm run dev
doppler run -- npm run dev

# Instead of: bun dev
doppler run -- bun dev

# Your code reads process.env.DATABASE_URL normally — no changes needed
```

### Adding Secrets

```bash
# Via CLI
doppler secrets set STRIPE_SECRET_KEY sk_live_xxx

# Or use the web dashboard at dashboard.doppler.com
```

### New Machine Recovery

```bash
brew install dopplerhq/cli/doppler
doppler login
# That's it. Navigate to any project and `doppler run` works.
```

---

## 2. Dotfiles (This Repo)

### Structure

```text
~/dotfiles/
├── README.md              # This file (documentation + runbook)
├── Brewfile               # All installed apps
├── install.sh             # Setup script for new machines
├── cursor/
│   ├── settings.json      # Cursor editor settings
│   ├── keybindings.json   # Custom keybindings
│   └── extensions.txt     # List of installed extensions
├── zsh/
│   └── .zshrc             # Shell configuration
├── git/
│   └── .gitconfig         # Git configuration
└── crontab/
    └── README.md          # Crontab documentation (see section 4)
```

### How Symlinks Work

The system expects config files in specific locations (e.g., `~/.zshrc`). Instead of copying files, we create **symbolic links** that point to this repo:

```bash
# Example: Link your .zshrc
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc

# Now when you edit ~/.zshrc, you're actually editing ~/dotfiles/zsh/.zshrc
# Which means changes are tracked in git
```

### Cursor Config Location (macOS)

Cursor stores settings at:

```text
~/Library/Application Support/Cursor/User/settings.json
~/Library/Application Support/Cursor/User/keybindings.json
```

To symlink:

```bash
ln -sf ~/dotfiles/cursor/settings.json ~/Library/Application\ Support/Cursor/User/settings.json
ln -sf ~/dotfiles/cursor/keybindings.json ~/Library/Application\ Support/Cursor/User/keybindings.json
```

### Exporting Cursor Extensions

```bash
# List current extensions
cursor --list-extensions > ~/dotfiles/cursor/extensions.txt

# Install from list (on new machine)
cat ~/dotfiles/cursor/extensions.txt | xargs -L 1 cursor --install-extension
```

### Backup Workflow

After making config changes:

```bash
cd ~/dotfiles
git add -A
git commit -m "Updated zshrc with new aliases"
git push
```

**Tip:** You could automate this with a cron job, but I prefer manual commits so the history stays meaningful.

---

## 3. Applications with Brewfile

### What It Captures

- CLI tools (`git`, `node`, `doppler`)
- GUI apps via Cask (`cursor`, `slack`, `figma`)
- Mac App Store apps via `mas`

### Generate Brewfile

```bash
# Dump your current installed apps
brew bundle dump --file=~/dotfiles/Brewfile --force
```

### Example Brewfile

```ruby
# Taps
tap "homebrew/bundle"
tap "dopplerhq/cli"

# CLI Tools
brew "git"
brew "node"
brew "bun"
brew "doppler"

# Applications (Casks)
cask "cursor"
cask "slack"
cask "figma"
cask "raycast"
cask "rectangle"
cask "1password"

# Mac App Store (requires: brew install mas)
mas "Xcode", id: 497799835
```

### Restore Apps on New Machine

```bash
brew bundle --file=~/dotfiles/Brewfile
```

### When to Update

Run `brew bundle dump` after:

- Installing a new app via `brew install` or `brew install --cask`
- Then commit the updated Brewfile

---

## 4. Crontab Jobs

macOS crontabs aren't easily portable (they're stored in system directories and tied to your user). Instead of trying to back up the raw crontab, I document my cron jobs here and recreate them manually.

### Current Cron Jobs

#### Obsidian Vault Auto-Commit (Optional)

Automatically commits and pushes changes to my Obsidian vault every 30 minutes.

```bash
# Edit crontab
crontab -e

# Add this line (runs every 30 minutes)
*/30 * * * * cd ~/Documents/obsidian-vault && git add -A && git diff-index --quiet HEAD || (git commit -m "Auto-commit: $(date '+\%Y-\%m-\%d \%H:\%M')" && git push)
```

**What it does:**

1. `cd ~/Documents/obsidian-vault` — Navigate to vault
2. `git add -A` — Stage all changes
3. `git diff-index --quiet HEAD` — Check if there are changes
4. `||` — If there ARE changes (command fails), then...
5. `git commit -m "..."` — Commit with timestamp
6. `git push` — Push to remote

**Note:** Make sure the vault path matches your actual Obsidian vault location.

### Viewing Current Crontab

```bash
crontab -l
```

### Removing All Cron Jobs

```bash
crontab -r
```

---

## 5. SSH Keys (Generate Fresh)

My strategy: **Generate new SSH keys on each machine.** This is more secure than backing up private keys.

### Generate New Keys

```bash
# Generate ED25519 key (modern, secure)
ssh-keygen -t ed25519 -C "juancamiloqhz@gmail.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key to clipboard
pbcopy < ~/.ssh/id_ed25519.pub
```

### Add to GitHub

1. Go to [GitHub SSH Settings](https://github.com/settings/keys)
2. Click "New SSH Key"
3. Paste the public key
4. Name it something like "MacBook Pro 2025"

### Test Connection

```bash
ssh -T git@github.com
# Should see: "Hi juancamiloqhz! You've successfully authenticated..."
```

---

## 6. New Machine Setup (Complete Checklist)

When setting up a fresh Mac, follow these steps in order:

### Phase 1: Foundation (5 min)

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH (Apple Silicon Macs)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install git (needed to clone dotfiles)
brew install git
```

### Phase 2: Clone & Install (5 min)

```bash
# Clone this repo
git clone https://github.com/juancamiloqhz/dotfiles.git ~/dotfiles

# Install all apps from Brewfile
brew bundle --file=~/dotfiles/Brewfile

# Run setup script (creates symlinks)
cd ~/dotfiles && chmod +x install.sh && ./install.sh
```

### Phase 3: Secrets (2 min)

```bash
# Login to Doppler
doppler login

# Verify
doppler projects
```

### Phase 4: SSH Keys (3 min)

```bash
# Generate new key
ssh-keygen -t ed25519 -C "juancamiloqhz@gmail.com"

# Add to agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key and add to GitHub
pbcopy < ~/.ssh/id_ed25519.pub
# Then: https://github.com/settings/keys
```

### Phase 5: Crontab (2 min)

```bash
# Re-add cron jobs from documentation above
crontab -e
```

### Phase 6: Manual Steps

- [ ] Sign into 1Password
- [ ] Sign into Cursor with GitHub
- [ ] Sign into Raycast
- [ ] Configure Rectangle shortcuts
- [ ] Sign into Slack workspaces
- [ ] Sign into Figma

---

## 7. Install Script

The `install.sh` script automates symlink creation. See the file for implementation.

**Usage:**

```bash
cd ~/dotfiles
./install.sh
```

**What it does:**

1. Backs up existing configs (if any)
2. Creates symlinks to this repo
3. Installs Cursor extensions from list

---

## Maintenance

### Weekly (optional)

- Commit any config changes

### After installing new apps

```bash
brew bundle dump --file=~/dotfiles/Brewfile --force
git add Brewfile && git commit -m "Added [app name]"
```

### After changing Cursor extensions

```bash
cursor --list-extensions > ~/dotfiles/cursor/extensions.txt
git add cursor/extensions.txt && git commit -m "Updated Cursor extensions"
```

### After changing crontab

- Update the documentation in this README

---

## Quick Reference

| I need to...                | Command                                                                         |
| --------------------------- | ------------------------------------------------------------------------------- |
| See my current crontab      | `crontab -l`                                                                    |
| Edit crontab                | `crontab -e`                                                                    |
| See Doppler secrets         | `doppler secrets`                                                               |
| Run dev server with secrets | `doppler run -- npm run dev`                                                    |
| Update Brewfile             | `brew bundle dump --file=~/dotfiles/Brewfile --force`                           |
| Export Cursor extensions    | `cursor --list-extensions > ~/dotfiles/cursor/extensions.txt`                   |
| Install Cursor extensions   | `cat ~/dotfiles/cursor/extensions.txt \| xargs -L 1 cursor --install-extension` |

---

## Resources

- [Doppler Documentation](https://docs.doppler.com)
- [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle)
- [GitHub: Adding SSH Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)
