#!/usr/bin/env bash
# Dedicated every-2-hour backup & sync of the Sofia database

set -euo pipefail

PICLOUD="/mnt/piCloud"
BACKUP_DIR="$PICLOUD/pi5-backup/sqlite-backups/sofia-q2h"
SOFIA_DB="/var/lib/shiny-data/sofia/sofia.sqlite"

mkdir -p "$BACKUP_DIR"

if [ -f "$SOFIA_DB" ]; then
    # Perform online SQLite backup with timestamp
    sqlite3 "$SOFIA_DB" ".backup '$BACKUP_DIR/sofia-backup-$(date +%Y%m%d-%H%M%S).sqlite'"
    
    # Keep 14 days of backups (14 * 12 = 168 files)
    find "$BACKUP_DIR" -name "sofia-backup-*.sqlite" -mtime +14 -delete
    
    # Sync immediately to Google Drive (very lightweight sync of just this folder)
    rclone sync "$BACKUP_DIR/" gdrive:systems-backups/pi5-backup/sqlite-backups/sofia-q2h/ --verbose
else
    echo "Error: Sofia database not found at $SOFIA_DB"
    exit 1
fi
