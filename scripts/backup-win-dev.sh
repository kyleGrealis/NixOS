#!/bin/bash
# Sync Windows dev folder to piCloud backup location safely with archival

set -e

SOURCE_DIR="/mnt/c/Users/kxg679/Documents/dev/"
BACKUP_DIR="$HOME/piCloud/work-backup/windows-dev/"
ARCHIVE_DIR="$HOME/piCloud/work-backup/archive-dev/"

DRY_RUN=""
if [[ "$1" == "--dry-run" ]] || [[ "$1" == "-d" ]]; then
    DRY_RUN="--dry-run"
    echo "DRY RUN: Previewing sync changes without copying..."
fi

echo "Syncing Windows dev folder to piCloud backup..."
echo "Source: $SOURCE_DIR"
echo "Target: $BACKUP_DIR"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Windows dev directory not found at $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$HOME/piCloud" ] || ! mountpoint -q "$HOME/piCloud"; then
    echo "ERROR: piCloud not mounted at $HOME/piCloud"
    exit 1
fi

if [ -z "$DRY_RUN" ]; then
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$ARCHIVE_DIR"
fi

if [ -n "$DRY_RUN" ]; then
    echo "DRY RUN: Checking for locally deleted projects that would be archived..."
    find "$BACKUP_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null | while read -r gitdir; do
        repo_backup_dir=$(dirname "$gitdir")
        relative_path="${repo_backup_dir#"$BACKUP_DIR"}"
        repo_source_dir="$SOURCE_DIR/$relative_path"
        if [ ! -d "$repo_source_dir" ]; then
            echo "Project '$relative_path' would be moved to archive-dev/$relative_path"
        fi
    done
else
    echo "Checking for locally deleted projects to archive..."
    find "$BACKUP_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null | while read -r gitdir; do
        repo_backup_dir=$(dirname "$gitdir")
        relative_path="${repo_backup_dir#"$BACKUP_DIR"}"
        repo_source_dir="$SOURCE_DIR/$relative_path"
        
        if [ ! -d "$repo_source_dir" ]; then
            archive_target="$ARCHIVE_DIR/$relative_path"
            echo "Project '$relative_path' was deleted locally. Archiving..."
            mkdir -p "$(dirname "$archive_target")"
            mv "$repo_backup_dir" "$archive_target"
        fi
    done
fi

EXCLUDES=(
    --exclude='node_modules/'
    --exclude='.venv/'
    --exclude='venv/'
    --exclude='.DS_Store'
    --exclude='.cache/'
    --exclude='.Rproj.user/'
    --exclude='.quarto/'
)

if rsync -rtH --delete --copy-unsafe-links --no-links --no-perms --no-owner --no-group --info=progress2 $DRY_RUN \
    "${EXCLUDES[@]}" \
    "$SOURCE_DIR" "$BACKUP_DIR"; then
    if [ -n "$DRY_RUN" ]; then
        echo "Dry run completed successfully!"
    else
        echo "Windows dev folder backup completed successfully!"
    fi
else
    echo "Sync failed!"
    exit 1
fi
