#!/usr/bin/env bash
# Robust daily backup for pi5 services and static files to piCloud (Samsung T9 exFAT)
# and sync to Google Drive via rclone.

set -euo pipefail

# Logging
LOG_FILE="/home/kyle/backup-nixPi5.log"
exec > >(tee -ia "$LOG_FILE") 2>&1

echo "============================================="
echo "Starting nixPi5 Backup: $(date)"
echo "============================================="

PICLOUD="/mnt/piCloud"
BACKUP_DIR="$PICLOUD/pi5-backup"

# 1. Ensure mounts and paths exist
if [ ! -d "$PICLOUD" ]; then
    echo "ERROR: $PICLOUD mount directory not found!"
    exit 1
fi

mkdir -p "$BACKUP_DIR/sqlite-backups"

# 2. ExFAT-compatible Rsync of Shiny Server Apps
echo "--- Backing up Shiny Server Apps ---"
rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
    --exclude="venv/" --exclude=".venv/" --exclude="node_modules/" --exclude="renv/library/" \
    /srv/shiny-server/ "$BACKUP_DIR/shiny-apps-deployed/"

# 3. ExFAT-compatible Rsync of Static Sites (slides)
echo "--- Backing up Static Sites (slides) ---"
rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
    --exclude="venv/" --exclude=".venv/" --exclude="node_modules/" --exclude="renv/library/" \
    /srv/slides/ "$BACKUP_DIR/static-slides-deployed/"

# 4. Safe Online SQLite Backup for Sofia Database
echo "--- Performing Online SQLite Backup of Sofia ---"
SOFIA_DB="/var/lib/shiny-data/sofia/sofia.sqlite"
if [ -f "$SOFIA_DB" ]; then
    sqlite3 "$SOFIA_DB" ".backup '$BACKUP_DIR/sqlite-backups/sofia-backup-$(date +%Y%m%d).sqlite'"
    # Clean up backups older than 7 days
    find "$BACKUP_DIR/sqlite-backups" -name "sofia-backup-*.sqlite" -mtime +7 -delete
else
    echo "Warning: Sofia database not found at $SOFIA_DB"
fi

# 5. Backup System Configurations & Dotfiles
echo "--- Backing up Configurations & Dotfiles ---"
mkdir -p "$BACKUP_DIR/dotfiles"
mkdir -p "$BACKUP_DIR/ssh"
mkdir -p "$BACKUP_DIR/configs"

# Copy configurations (excluding declarative settings managed by Nix/Home Manager)
cp -f /home/kyle/.config/rclone/rclone.conf "$BACKUP_DIR/configs/rclone.conf" || true
cp -f /home/kyle/.cloudflared/*.json "$BACKUP_DIR/configs/" || true

# Copy Antigravity CLI and Gemini/Claude authentication credentials
mkdir -p "$BACKUP_DIR/configs/gemini"
cp -f /home/kyle/.gemini/*.json "$BACKUP_DIR/configs/gemini/" || true
cp -f /home/kyle/.gemini/installation_id "$BACKUP_DIR/configs/gemini/" || true
mkdir -p "$BACKUP_DIR/configs/claude"
cp -f /home/kyle/.claude/.credentials.json "$BACKUP_DIR/configs/claude/.credentials.json" || true
cp -f /home/kyle/.claude/settings.local.json "$BACKUP_DIR/configs/claude/settings.local.json" || true

# Copy Tailscale State (requires sudo)
echo "--- Backing up Tailscale State ---"
sudo cp -f /var/lib/tailscale/tailscaled.state "$BACKUP_DIR/configs/tailscaled.state" || true

# Copy shell and dev profiles containing credentials (excluding declarative configs)
cp -f /home/kyle/.env "$BACKUP_DIR/dotfiles/.env" || true
cp -f /home/kyle/.claude.json "$BACKUP_DIR/dotfiles/.claude.json" || true
cp -f /home/kyle/dev/agentic-memory-compiler/.env "$BACKUP_DIR/configs/agentic-memory-compiler.env" || true
cp -f /home/kyle/.Renviron "$BACKUP_DIR/dotfiles/.Renviron" || true

# Copy public SSH metadata (excluding private key and declarative ~/.ssh/config)
cp -f /home/kyle/.ssh/authorized_keys "$BACKUP_DIR/ssh/authorized_keys" || true
cp -f /home/kyle/.ssh/id_ed25519.pub "$BACKUP_DIR/ssh/id_ed25519.pub" || true

# Copy active MCP server credential/token folders
for mcp in gmail-mcp google-calendar-mcp google-drive-mcp github-mcp; do
    if [ -d "/home/kyle/.config/$mcp" ]; then
        mkdir -p "$BACKUP_DIR/configs/$mcp"
        rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
            --exclude="node_modules/" \
            /home/kyle/.config/$mcp/ "$BACKUP_DIR/configs/$mcp/" || true
    fi
done

# Copy Syncthing cryptographic identity (keys only, folder structure is managed by Nix)
if [ -d "/home/kyle/.local/state/syncthing" ]; then
    mkdir -p "$BACKUP_DIR/configs/syncthing"
    cp -f /home/kyle/.local/state/syncthing/key.pem "$BACKUP_DIR/configs/syncthing/key.pem" || true
    cp -f /home/kyle/.local/state/syncthing/cert.pem "$BACKUP_DIR/configs/syncthing/cert.pem" || true
fi

# Safe Online SQLite Backup for Qwerty and Milton Databases
echo "--- Performing Online SQLite Backup of Qwerty & Milton ---"
QWERTY_DB="/home/kyle/geminiOS/data/qwerty.db"
MILTON_DB="/home/kyle/milton/data/milton.db"
if [ -f "$QWERTY_DB" ]; then
    sqlite3 "$QWERTY_DB" ".backup '$BACKUP_DIR/sqlite-backups/qwerty-backup-$(date +%Y%m%d).sqlite'"
    # Clean up backups older than 7 days
    find "$BACKUP_DIR/sqlite-backups" -name "qwerty-backup-*.sqlite" -mtime +7 -delete
fi
if [ -f "$MILTON_DB" ]; then
    sqlite3 "$MILTON_DB" ".backup '$BACKUP_DIR/sqlite-backups/milton-backup-$(date +%Y%m%d).sqlite'"
    # Clean up backups older than 7 days
    find "$BACKUP_DIR/sqlite-backups" -name "milton-backup-*.sqlite" -mtime +7 -delete
fi

# Copy geminiOS (Qwerty Bot) codebase, keys, and env credentials (excluding active SQLite files)
if [ -d "/home/kyle/geminiOS" ]; then
    echo "--- Backing up geminiOS (Qwerty) ---"
    rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
        --exclude="node_modules/" --exclude="data/*.db" --exclude="data/*.db-wal" --exclude="data/*.db-shm" \
        /home/kyle/geminiOS/ "$BACKUP_DIR/geminiOS/" || true
fi

# Copy Milton Bot codebase and env credentials (excluding active SQLite files)
if [ -d "/home/kyle/milton" ]; then
    echo "--- Backing up Milton Bot ---"
    rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
        --exclude="node_modules/" --exclude="data/*.db" --exclude="data/*.db-wal" --exclude="data/*.db-shm" \
        /home/kyle/milton/ "$BACKUP_DIR/milton/" || true
fi

# Copy OneCLI configurations
if [ -d "/home/kyle/.onecli" ]; then
    echo "--- Backing up OneCLI config ---"
    rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
        /home/kyle/.onecli/ "$BACKUP_DIR/onecli-config/" || true
fi

# Backup Docker configurations and volume data
echo "--- Backing up OneCLI PostgreSQL Database ---"
mkdir -p "$BACKUP_DIR/docker-volumes"
if docker ps --format '{{.Names}}' | grep -q "^onecli-postgres-1$"; then
    echo "Performing online pg_dump..."
    docker exec -t onecli-postgres-1 pg_dump -U onecli onecli > "$BACKUP_DIR/docker-volumes/onecli_postgres.sql" || true
else
    echo "Container onecli-postgres-1 is offline, falling back to volume tarball..."
    docker run --rm -v onecli_pgdata:/volume -v "$BACKUP_DIR/docker-volumes":/backup alpine tar czf /backup/onecli_pgdata.tar.gz -C /volume . || true
fi

# Backup OneCLI application data (app-data volume)
echo "--- Backing up OneCLI App-Data Volume ---"
docker run --rm -v onecli_app-data:/volume -v "$BACKUP_DIR/docker-volumes":/backup alpine tar czf /backup/onecli_app-data.tar.gz -C /volume . || true


# 5.5 Backup Obsidian Vault (Syncthing keeps it in sync, but this creates a historical backup)
echo "--- Backing up Obsidian Vault ---"
if [ -d "/home/kyle/Documents/obsidian" ]; then
    rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
        --exclude=".stversions/" --exclude=".stfolder/" \
        /home/kyle/Documents/obsidian/ "$BACKUP_DIR/obsidian-vault/" || true
fi

# 6. Rclone Sync entire piCloud to Google Drive
echo "--- Syncing piCloud to Google Drive ---"
rclone sync "$PICLOUD/" gdrive:systems-backups --exclude ".Trash-*/**" --exclude "academic/**" --verbose

echo "============================================="
echo "Backup Completed Successfully: $(date)"
echo "============================================="
