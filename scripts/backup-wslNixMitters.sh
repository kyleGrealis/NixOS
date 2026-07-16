#!/bin/bash
# Local backup script for wslNixMitters (WSL) configurations and profiles
# Saves directly to the mounted piCloud share (which pi5 syncs to Google Drive).

set -e

echo "============================================="
echo "Starting wslNixMitters Local Backup: $(date)"
echo "============================================="

PICLOUD="/home/kyle/piCloud"
BACKUP_DIR="$PICLOUD/wslNixMitters-backup"

# Ensure piCloud is mounted
if [ ! -d "$PICLOUD" ] || ! mountpoint -q "$PICLOUD"; then
    echo "ERROR: piCloud mount directory not found or not mounted at $PICLOUD!"
    exit 1
fi

mkdir -p "$BACKUP_DIR/dotfiles"
mkdir -p "$BACKUP_DIR/ssh"

# 1. Copy work-specific mutable shell and dev environment credentials/secrets
cp -f /home/kyle/.Renviron "$BACKUP_DIR/dotfiles/.Renviron" || true
cp -f /home/kyle/.env "$BACKUP_DIR/dotfiles/.env" || true
cp -f /home/kyle/.smbcredentials "$BACKUP_DIR/dotfiles/.smbcredentials" || true
cp -f /home/kyle/.claude.json "$BACKUP_DIR/dotfiles/.claude.json" || true

# 2. Copy public SSH identity metadata
cp -f /home/kyle/.ssh/authorized_keys "$BACKUP_DIR/ssh/authorized_keys" || true
cp -f /home/kyle/.ssh/id_ed25519.pub "$BACKUP_DIR/ssh/id_ed25519.pub" || true

echo "============================================="
echo "wslNixMitters Backup Completed: $(date)"
echo "============================================="
