#!/usr/bin/env bash
# Automated restoration script for nixPi5 services, codebases, databases, and credentials.
# This script must be executed on the nixPi5 server itself after booting and mounting the T9 SSD.

set -euo pipefail

BACKUP_DIR="/mnt/piCloud/pi5-backup"
TARGET_USER="kyle"
TARGET_UID=1002
TARGET_GID=1002

echo "============================================="
echo "Starting nixPi5 Service & Data Restoration"
echo "============================================="

# 1. Verification checks
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (sudo)."
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found at $BACKUP_DIR."
    echo "Please ensure the external T9 SSD is mounted at /mnt/piCloud."
    exit 1
fi

# 2. System Paths & Permissions
echo "--- Creating system paths and setting permissions ---"
mkdir -p /srv/shiny-server /srv/slides /var/lib/shiny-data/sofia /var/lib/github-runners
chown -R $TARGET_UID:$TARGET_GID /srv/shiny-server /srv/slides /var/lib/shiny-data /var/lib/github-runners

# 3. Restore Web Applications & Static Slides
echo "--- Restoring Shiny Server Source, Apps, and RevealJS Slides ---"
rsync -avh "$BACKUP_DIR/shiny-server-source/" /srv/shiny-server/
rsync -avh "$BACKUP_DIR/shiny-apps-deployed/" /srv/shiny-server/
rsync -avh "$BACKUP_DIR/static-slides-deployed/" /srv/slides/

echo "--- Rebuilding Shiny Server Node dependencies ---"
cd /srv/shiny-server
sudo -u $TARGET_USER npm rebuild
cd -

echo "--- Symlinking Sofia Database ---"
rm -f /srv/shiny-server/sofia/sofia.sqlite
ln -s /var/lib/shiny-data/sofia/sofia.sqlite /srv/shiny-server/sofia/sofia.sqlite

# 4. Restore Bot Codebases & Repositories
echo "--- Restoring geminiOS and milton codebases ---"
sudo -u $TARGET_USER mkdir -p /home/$TARGET_USER/geminiOS /home/$TARGET_USER/milton
rsync -avh "$BACKUP_DIR/geminiOS/" /home/$TARGET_USER/geminiOS/
rsync -avh "$BACKUP_DIR/milton/" /home/$TARGET_USER/milton/
chown -R $TARGET_UID:$TARGET_GID /home/$TARGET_USER/geminiOS /home/$TARGET_USER/milton

# 5. Restore SQLite Databases
echo "--- Restoring SQLite Databases ---"
sudo mkdir -p /var/lib/shiny-data/sofia
# Locate the latest backup file matching the pattern sofia-backup-*.sqlite (including 2-hourly subdirectories)
LATEST_SOFIA=$(find $BACKUP_DIR/sqlite-backups/ -name "sofia-backup-*.sqlite" 2>/dev/null | sort | tail -n 1)
if [ -n "$LATEST_SOFIA" ]; then
    echo "Restoring Sofia database from $LATEST_SOFIA..."
    cp -f "$LATEST_SOFIA" /var/lib/shiny-data/sofia/sofia.sqlite
    chown $TARGET_UID:$TARGET_GID /var/lib/shiny-data/sofia/sofia.sqlite
    chmod 0600 /var/lib/shiny-data/sofia/sofia.sqlite
else
    echo "Warning: Sofia database backup not found, please manually copy the latest version."
fi

echo "--- Restoring Qwerty and Milton databases ---"
mkdir -p /home/$TARGET_USER/geminiOS/data /home/$TARGET_USER/milton/data

LATEST_QWERTY=$(ls -t "$BACKUP_DIR"/sqlite-backups/qwerty-backup-*.sqlite 2>/dev/null | head -n 1)
if [ -n "$LATEST_QWERTY" ]; then
    echo "Restoring Qwerty database from $LATEST_QWERTY..."
    cp -f "$LATEST_QWERTY" /home/$TARGET_USER/geminiOS/data/qwerty.db
fi

LATEST_MILTON=$(ls -t "$BACKUP_DIR"/sqlite-backups/milton-backup-*.sqlite 2>/dev/null | head -n 1)
if [ -n "$LATEST_MILTON" ]; then
    echo "Restoring Milton database from $LATEST_MILTON..."
    cp -f "$LATEST_MILTON" /home/$TARGET_USER/milton/data/milton.db
fi

chown -R $TARGET_UID:$TARGET_GID /home/$TARGET_USER/geminiOS/data /home/$TARGET_USER/milton/data

# 6. Restore User Configurations & Dotfiles
echo "--- Restoring user configs and profiles ---"
for file in .bashrc .bash_profile .bash_aliases .gitconfig .Rprofile .Renviron .env; do
    if [ -f "$BACKUP_DIR/dotfiles/$file" ]; then
        cp -f "$BACKUP_DIR/dotfiles/$file" /home/$TARGET_USER/$file
    fi
done

# User scripts
echo "--- Restoring user scripts ---"
mkdir -p /home/$TARGET_USER/scripts
rsync -avh "$BACKUP_DIR/scripts/" /home/$TARGET_USER/scripts/

# SSH Configuration
mkdir -p /home/$TARGET_USER/.ssh
cp -f "$BACKUP_DIR/ssh/config" /home/$TARGET_USER/.ssh/config
cp -f "$BACKUP_DIR/ssh/authorized_keys" /home/$TARGET_USER/.ssh/authorized_keys
cp -f "$BACKUP_DIR/ssh/id_ed25519.pub" /home/$TARGET_USER/.ssh/id_ed25519.pub
chmod 700 /home/$TARGET_USER/.ssh
chmod 600 /home/$TARGET_USER/.ssh/*

# Rclone Config
mkdir -p /home/$TARGET_USER/.config/rclone
cp -f "$BACKUP_DIR/configs/rclone.conf" /home/$TARGET_USER/.config/rclone/rclone.conf

# Cloudflare Tunnel JSON Credentials
mkdir -p /var/lib/cloudflare-tunnels/
cp -f "$BACKUP_DIR/configs/"b76baf87-cb41-4c3e-98fd-27b806a38569.json /var/lib/cloudflare-tunnels/
chown root:root /var/lib/cloudflare-tunnels/b76baf87-cb41-4c3e-98fd-27b806a38569.json
chmod 0400 /var/lib/cloudflare-tunnels/b76baf87-cb41-4c3e-98fd-27b806a38569.json

# MCP Server Credentials
cp -rf "$BACKUP_DIR/configs/"*-mcp /home/$TARGET_USER/.config/ || true

# Syncthing State
mkdir -p /home/$TARGET_USER/.local/state/syncthing
rsync -avh "$BACKUP_DIR/configs/syncthing/" /home/$TARGET_USER/.local/state/syncthing/

# AI settings
mkdir -p /home/$TARGET_USER/.gemini/antigravity-cli /home/$TARGET_USER/.claude
cp -f "$BACKUP_DIR/configs/gemini/"* /home/$TARGET_USER/.gemini/ || true
cp -f "$BACKUP_DIR/configs/agy-settings.json" /home/$TARGET_USER/.gemini/antigravity-cli/settings.json || true
cp -f "$BACKUP_DIR/configs/claude/.credentials.json" /home/$TARGET_USER/.claude/.credentials.json || true
cp -f "$BACKUP_DIR/configs/claude/settings.local.json" /home/$TARGET_USER/.claude/settings.local.json || true
cp -f "$BACKUP_DIR/configs/claude-settings.json" /home/$TARGET_USER/.claude/settings.json || true

# Obsidian Vault Seed
mkdir -p /home/$TARGET_USER/Documents/obsidian
rsync -avh "$BACKUP_DIR/obsidian-vault/" /home/$TARGET_USER/Documents/obsidian/

# Ensure all home files owned by kyle
chown -R $TARGET_UID:$TARGET_GID /home/$TARGET_USER/

# 7. Restore Docker volumes
echo "--- Restoring Docker Volumes ---"
docker volume create onecli_pgdata || true
docker volume create onecli_app-data || true
docker run --rm -v onecli_pgdata:/volume -v "$BACKUP_DIR/docker-volumes":/backup alpine sh -c "tar xzf /backup/onecli_pgdata.tar.gz -C /volume" || true
docker run --rm -v onecli_app-data:/volume -v "$BACKUP_DIR/docker-volumes":/backup alpine sh -c "tar xzf /backup/onecli_app-data.tar.gz -C /volume" || true

# 8. Create Syncthing & Sandbox Directories
echo "--- Creating required Syncthing and Sandbox Directories ---"
sudo -u $TARGET_USER mkdir -p /home/$TARGET_USER/Documents/obsidian/.stfolder
sudo -u $TARGET_USER mkdir -p /home/$TARGET_USER/dev/agentic-memory-compiler/.stfolder
sudo -u $TARGET_USER mkdir -p /home/$TARGET_USER/.gemini/state /home/$TARGET_USER/.gemini/tmp/kyle

# 9. Prompt for manual Samba setup
echo "============================================="
echo "Restoration Complete!"
echo "============================================="
echo "Manual next steps:"
echo "1. Run 'sudo smbpasswd -a kyle' to set the Samba password."
echo "2. Populate your GitHub Action Tokens inside '/var/lib/github-runners/':"
echo "   - baby-tracker.token"
echo "   - r2-dashboard.token"
echo "   - sofia.token"
echo "3. Run 'systemctl --user daemon-reload' and enable bot services/timers."
echo "============================================="
