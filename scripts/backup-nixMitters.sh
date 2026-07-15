#!/bin/bash
# Local backup script for archMitters configurations and profiles
# Saves directly to the mounted piCloud share (which pi5 syncs to Google Drive).

set -e

echo "============================================="
echo "Starting nixMitters Local Backup: $(date)"
echo "============================================="

PICLOUD="/home/kyle/piCloud"
BACKUP_DIR="$PICLOUD/nixMitters-backup"

# Ensure piCloud is mounted
if [ ! -d "$PICLOUD" ]; then
    echo "ERROR: piCloud mount directory not found at $PICLOUD!"
    exit 1
fi

mkdir -p "$BACKUP_DIR/dotfiles"
mkdir -p "$BACKUP_DIR/ssh"
mkdir -p "$BACKUP_DIR/configs"

# 1. Copy shell and dev profiles
cp -f /home/kyle/.bashrc "$BACKUP_DIR/dotfiles/.bashrc" || true
cp -f /home/kyle/.bash_profile "$BACKUP_DIR/dotfiles/.bash_profile" || true
cp -f /home/kyle/.zshrc "$BACKUP_DIR/dotfiles/.zshrc" || true
cp -f /home/kyle/.bash_aliases "$BACKUP_DIR/dotfiles/.bash_aliases" || true
cp -f /home/kyle/.gitconfig "$BACKUP_DIR/dotfiles/.gitconfig" || true
cp -f /home/kyle/.Rprofile "$BACKUP_DIR/dotfiles/.Rprofile" || true
cp -f /home/kyle/.Renviron "$BACKUP_DIR/dotfiles/.Renviron" || true

# 2. Copy public SSH metadata
cp -f /home/kyle/.ssh/config "$BACKUP_DIR/ssh/config" || true
cp -f /home/kyle/.ssh/authorized_keys "$BACKUP_DIR/ssh/authorized_keys" || true
cp -f /home/kyle/.ssh/id_ed25519.pub "$BACKUP_DIR/ssh/id_ed25519.pub" || true

# 3. Copy Agent Configurations
cp -f /home/kyle/.gemini/antigravity-cli/settings.json "$BACKUP_DIR/configs/agy-settings.json" || true
cp -f /home/kyle/.claude/settings.json "$BACKUP_DIR/configs/claude-settings.json" || true

# 4. Copy Syncthing folder configurations
if [ -d "/home/kyle/.config/syncthing" ]; then
    mkdir -p "$BACKUP_DIR/configs/syncthing"
    rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
        --exclude="index-*" --exclude="*.db" \
        /home/kyle/.config/syncthing/ "$BACKUP_DIR/configs/syncthing/" || true
fi

echo "============================================="
echo "archMitters Backup Completed: $(date)"
echo "============================================="
