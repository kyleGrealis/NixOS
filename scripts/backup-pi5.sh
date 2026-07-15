#!/usr/bin/env bash
# Robust daily backup for pi5 services and static files to piCloud (Samsung T9 exFAT)
# and sync to Google Drive via rclone.

set -euo pipefail

# Logging
LOG_FILE="/home/kyle/backup-pi5.log"
exec > >(tee -ia "$LOG_FILE") 2>&1

echo "============================================="
echo "Starting pi5 Backup: $(date)"
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

# Copy configurations
cp -f /etc/cloudflared/config.yml "$BACKUP_DIR/configs/cloudflared-config.yml" || true
cp -f /etc/shiny-server/shiny-server.conf "$BACKUP_DIR/configs/shiny-server.conf" || true
cp -f /home/kyle/.config/rclone/rclone.conf "$BACKUP_DIR/configs/rclone.conf" || true
cp -f /home/kyle/.gemini/antigravity-cli/settings.json "$BACKUP_DIR/configs/agy-settings.json" || true
cp -f /home/kyle/.claude/settings.json "$BACKUP_DIR/configs/claude-settings.json" || true
cp -f /home/kyle/.cloudflared/*.json "$BACKUP_DIR/configs/" || true

# Copy shell and dev profiles (including critical .env variables file!)
cp -f /home/kyle/.env "$BACKUP_DIR/dotfiles/.env" || true
cp -f /home/kyle/dev/agentic-memory-compiler/.env "$BACKUP_DIR/configs/agentic-memory-compiler.env" || true
cp -f /home/kyle/.bashrc "$BACKUP_DIR/dotfiles/.bashrc" || true
cp -f /home/kyle/.bash_profile "$BACKUP_DIR/dotfiles/.bash_profile" || true
cp -f /home/kyle/.zshrc "$BACKUP_DIR/dotfiles/.zshrc" || true
cp -f /home/kyle/.bash_aliases "$BACKUP_DIR/dotfiles/.bash_aliases" || true
cp -f /home/kyle/.gitconfig "$BACKUP_DIR/dotfiles/.gitconfig" || true
cp -f /home/kyle/.Rprofile "$BACKUP_DIR/dotfiles/.Rprofile" || true
cp -f /home/kyle/.Renviron "$BACKUP_DIR/dotfiles/.Renviron" || true

# Copy public SSH metadata (excluding private key)
cp -f /home/kyle/.ssh/config "$BACKUP_DIR/ssh/config" || true
cp -f /home/kyle/.ssh/authorized_keys "$BACKUP_DIR/ssh/authorized_keys" || true
cp -f /home/kyle/.ssh/id_ed25519.pub "$BACKUP_DIR/ssh/id_ed25519.pub" || true

# Copy active custom user scripts (critical!)
if [ -d "/home/kyle/scripts" ]; then
    mkdir -p "$BACKUP_DIR/scripts"
    rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
        /home/kyle/scripts/ "$BACKUP_DIR/scripts/" || true
fi

# Copy active MCP server credential/token folders
for mcp in gmail-mcp google-calendar-mcp google-drive-mcp github-mcp; do
    if [ -d "/home/kyle/.config/$mcp" ]; then
        mkdir -p "$BACKUP_DIR/configs/$mcp"
        rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
            --exclude="node_modules/" \
            /home/kyle/.config/$mcp/ "$BACKUP_DIR/configs/$mcp/" || true
    fi
done

# Copy Syncthing folder configurations (excluding database index files to keep it lightweight)
if [ -d "/home/kyle/.local/state/syncthing" ]; then
    mkdir -p "$BACKUP_DIR/configs/syncthing"
    rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
        --exclude="index-*" --exclude="*.db" \
        /home/kyle/.local/state/syncthing/ "$BACKUP_DIR/configs/syncthing/" || true
fi

# Copy systemd units
rsync -rtv --no-links --no-perms --no-owner --no-group --modify-window=2 \
    /etc/systemd/system/shiny-server.service \
    /etc/systemd/system/slides-server.service \
    /etc/systemd/system/cloudflared.service \
    /etc/systemd/system/actions.runner.*.service \
    "$BACKUP_DIR/systemd/" || true

# Copy systemd user units (bot services and maintenance tasks)
echo "--- Backing up systemd user units ---"
mkdir -p "$BACKUP_DIR/systemd-user"
cp -f /home/kyle/.config/systemd/user/*.service "$BACKUP_DIR/systemd-user/" || true
cp -f /home/kyle/.config/systemd/user/*.timer "$BACKUP_DIR/systemd-user/" || true

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
    docker run --rm -v pgdata:/volume -v "$BACKUP_DIR/docker-volumes":/backup alpine tar czf /backup/pgdata.tar.gz -C /volume . || true
fi

# Backup OneCLI application data (app-data volume)
echo "--- Backing up OneCLI App-Data Volume ---"
docker run --rm -v app-data:/volume -v "$BACKUP_DIR/docker-volumes":/backup alpine tar czf /backup/app-data.tar.gz -C /volume . || true


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
