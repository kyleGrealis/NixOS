#!/bin/bash
# Local backup script for nixMitters configurations and profiles
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
mkdir -p "$BACKUP_DIR/keyrings"

# 1. Copy mutable shell and dev environment credentials/secrets
cp -f /home/kyle/.Renviron "$BACKUP_DIR/dotfiles/.Renviron" || true
cp -f /home/kyle/.env "$BACKUP_DIR/dotfiles/.env" || true
cp -f /home/kyle/.app-spec-pw "$BACKUP_DIR/dotfiles/.app-spec-pw" || true
cp -f /home/kyle/.smbcredentials "$BACKUP_DIR/dotfiles/.smbcredentials" || true
cp -f /home/kyle/.claude.json "$BACKUP_DIR/dotfiles/.claude.json" || true

# 1.5 Copy GNOME Keyring credentials (keyring databases and keystores)
if [ -d "/home/kyle/.local/share/keyrings" ]; then
    cp -f /home/kyle/.local/share/keyrings/* "$BACKUP_DIR/keyrings/" || true
fi

# 2. Copy public SSH identity metadata (excluding private key and declarative config)
cp -f /home/kyle/.ssh/authorized_keys "$BACKUP_DIR/ssh/authorized_keys" || true
cp -f /home/kyle/.ssh/id_ed25519.pub "$BACKUP_DIR/ssh/id_ed25519.pub" || true

# Note: Agent settings (agy-settings.json, claude-settings.json) are skipped as they are managed via declarative Home Manager symlinks to the Obsidian vault.

# 3. Copy Syncthing cryptographic identity (keys only, folder structure is managed by Nix)
if [ -d "/home/kyle/.config/syncthing" ]; then
    mkdir -p "$BACKUP_DIR/configs/syncthing"
    cp -f /home/kyle/.config/syncthing/key.pem "$BACKUP_DIR/configs/syncthing/key.pem" || true
    cp -f /home/kyle/.config/syncthing/cert.pem "$BACKUP_DIR/configs/syncthing/cert.pem" || true
fi

echo "============================================="
echo "nixMitters Backup Completed: $(date)"
echo "============================================="
