#!/bin/bash
# Sync $HOME/dev to piCloud backup location

set -e

SOURCE_DIR="$HOME/dev/"
BACKUP_DIR="$HOME/piCloud/work-backup/dev/"

echo "Syncing dev folder to piCloud backup..."
echo "Source: $SOURCE_DIR"
echo "Target: $BACKUP_DIR"

# Check if piCloud is mounted
if [ ! -d "$HOME/piCloud" ] || ! mountpoint -q "$HOME/piCloud"; then
    echo "ERROR: piCloud not mounted at $HOME/piCloud"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

EXCLUDES=(
    --exclude='node_modules/'
    --exclude='.venv/'
    --exclude='venv/'
    --exclude='.DS_Store'
    --exclude='.cache/'
    --exclude='.Rproj.user/'
    --exclude='.quarto/'
)

if rsync -rtH --delete --copy-unsafe-links --no-links --no-perms --no-owner --no-group --info=progress2 \
    "${EXCLUDES[@]}" \
    "$SOURCE_DIR" "$BACKUP_DIR"; then
    echo "Dev folder backup completed successfully!"
    echo "Backup location: $BACKUP_DIR"
else
    echo "Backup failed!"
    exit 1
fi
