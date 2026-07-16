#!/usr/bin/env python3
"""
Hardened restoration script for NixOS fleet configurations and databases.
Supports both nixPi5 and nixMitters targets with validation, dry-run,
SQLite integrity checks, and systemd service state management.

Usage:
    sudo python3 restore.py --host nixPi5 --backup-dir /mnt/piCloud/pi5-backup
    sudo python3 restore.py --host nixMitters --backup-dir /home/kyle/piCloud/nixMitters-backup --dry-run
"""

from __future__ import annotations

import argparse
import logging
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

TARGET_UID = 1002  # kyle GID/UID on nixPi5
TARGET_GID = 1002

def check_root() -> None:
    """Ensure script is run with root permissions for system paths."""
    if os.getuid() != 0:
        logging.error("This script must be run as root (sudo).")
        sys.exit(1)

def run_cmd(cmd: list[str], dry_run: bool = False, capture: bool = False) -> subprocess.CompletedProcess | None:
    """Run system commands safely with dry-run support."""
    cmd_str = " ".join(cmd)
    if dry_run:
        logging.info("[DRY-RUN] Would execute: %s", cmd_str)
        return None

    logging.info("Executing: %s", cmd_str)
    try:
        res = subprocess.run(cmd, check=True, capture_output=capture, text=True)
        return res
    except subprocess.CalledProcessError as e:
        logging.error("Command failed: %s", cmd_str)
        if e.stderr:
            logging.error("Error output: %s", e.stderr.strip())
        raise

def manage_systemd_service(service: str, action: str, user: bool = False, dry_run: bool = False) -> None:
    """Start or stop systemd services safely."""
    cmd = ["systemctl"]
    if user:
        # Run systemctl as target user kyle for user-level services
        cmd = ["sudo", "-u", "kyle", "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1002/bus", "systemctl", "--user"]
    
    cmd.extend([action, service])
    try:
        run_cmd(cmd, dry_run=dry_run)
    except Exception:
        logging.warning("Failed to perform %s on %s service (might not be loaded yet).", action, service)

def verify_sqlite_integrity(db_path: Path, dry_run: bool = False) -> bool:
    """Perform a PRAGMA integrity check on a restored SQLite database."""
    if dry_run or not db_path.exists():
        return True

    logging.info("Verifying SQLite integrity for: %s", db_path.name)
    try:
        res = subprocess.run(
            ["sqlite3", str(db_path), "PRAGMA integrity_check;"],
            capture_output=True,
            text=True,
            check=True
        )
        output = res.stdout.strip()
        if output == "ok":
            logging.info("Integrity check PASSED for %s", db_path.name)
            return True
        else:
            logging.error("Integrity check FAILED for %s: %s", db_path.name, output)
            return False
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        logging.error("Could not verify SQLite database integrity: %s", e)
        return False

def chown_kyle(path: Path, dry_run: bool = False) -> None:
    """Recursively set ownership to kyle:kyle (or root if not applicable)."""
    if dry_run or not path.exists():
        return
    try:
        # Use target UID/GID of kyle
        shutil.chown(path, user=TARGET_UID, group=TARGET_GID)
        for root, dirs, files in os.walk(path):
            for d in dirs:
                shutil.chown(Path(root) / d, user=TARGET_UID, group=TARGET_GID)
            for f in files:
                shutil.chown(Path(root) / f, user=TARGET_UID, group=TARGET_GID)
    except Exception as e:
        logging.warning("Failed to set ownership for %s: %s", path, e)

def restore_files(src: Path, dest: Path, dry_run: bool = False, is_dir: bool = False) -> None:
    """Safe wrapper around file/directory copies with validation."""
    if not src.exists():
        logging.warning("Source backup path not found: %s", src)
        return

    if dry_run:
        logging.info("[DRY-RUN] Copying %s -> %s", src, dest)
        return

    logging.info("Restoring: %s -> %s", src.name, dest)
    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        if is_dir:
            if dest.exists():
                shutil.rmtree(dest)
            shutil.copytree(src, dest, symlinks=True)
        else:
            shutil.copy2(src, dest)
        
        # Ensure kyle is owner if copying into /home/kyle or user directories
        if str(dest).startswith("/home/kyle") or str(dest).startswith("/srv"):
            chown_kyle(dest)
    except Exception as e:
        logging.error("Failed to copy %s to %s: %s", src, dest, e)
        raise

def restore_nixPi5(backup_dir: Path, dry_run: bool = False) -> None:
    """Execute hardened restoration steps for nixPi5 server."""
    logging.info("=== Commencing nixPi5 Restoration ===")
    
    # 1. Stop active services to prevent write locks / corruption
    logging.info("Step 1: Stopping active services...")
    manage_systemd_service("shiny-server.service", "stop", user=False, dry_run=dry_run)
    manage_systemd_service("geminios.service", "stop", user=True, dry_run=dry_run)
    manage_systemd_service("milton.service", "stop", user=True, dry_run=dry_run)

    # 2. Re-create base paths
    logging.info("Step 2: Restoring web application directories...")
    srv_shiny = Path("/srv/shiny-server")
    srv_slides = Path("/srv/slides")
    
    if not dry_run:
        srv_shiny.mkdir(parents=True, exist_ok=True)
        srv_slides.mkdir(parents=True, exist_ok=True)
        chown_kyle(srv_shiny)
        chown_kyle(srv_slides)

    # 3. Restore Shiny Apps and Slides
    restore_files(backup_dir / "shiny-apps-deployed", srv_shiny, dry_run=dry_run, is_dir=True)
    restore_files(backup_dir / "static-slides-deployed", srv_slides, dry_run=dry_run, is_dir=True)

    # 4. Disable renv autoloading to force Nix R package packages
    if not dry_run:
        logging.info("Step 4: Bypassing renv autoloading in Shiny apps...")
        for app in srv_shiny.iterdir():
            rprofile = app / ".Rprofile"
            if rprofile.exists():
                logging.info("Disabling .Rprofile for %s", app.name)
                rprofile.rename(app / ".Rprofile.disabled")

    # 5. Restore Codebases
    logging.info("Step 5: Restoring user codebases...")
    restore_files(backup_dir / "geminiOS", Path("/home/kyle/geminiOS"), dry_run=dry_run, is_dir=True)
    restore_files(backup_dir / "milton", Path("/home/kyle/milton"), dry_run=dry_run, is_dir=True)

    # 6. Restore SQLite Databases
    logging.info("Step 6: Restoring databases...")
    sqlite_backup_dir = backup_dir / "sqlite-backups"
    
    # Find latest databases
    dbs = {
        "sofia.sqlite": (Path("/var/lib/shiny-data/sofia/sofia.sqlite"), "sofia-backup-*.sqlite"),
        "qwerty.db": (Path("/home/kyle/geminiOS/data/qwerty.db"), "qwerty-backup-*.sqlite"),
        "milton.db": (Path("/home/kyle/milton/data/milton.db"), "milton-backup-*.sqlite")
    }

    for db_name, (dest_path, pattern) in dbs.items():
        candidates = sorted(sqlite_backup_dir.glob(pattern))
        if candidates:
            latest = candidates[-1]
            restore_files(latest, dest_path, dry_run=dry_run)
            if not verify_sqlite_integrity(dest_path, dry_run=dry_run):
                logging.error("WARNING: SQLite database %s is corrupted!", db_name)
        else:
            logging.warning("No SQLite backup found matching pattern %s", pattern)

    # 7. Restore User Dotfiles and Configs
    logging.info("Step 7: Restoring user config profile dotfiles...")
    dotfiles = [".bashrc", ".bash_profile", ".bash_aliases", ".gitconfig", ".Rprofile", ".Renviron", ".env"]
    for dot in dotfiles:
        restore_files(backup_dir / "dotfiles" / dot, Path(f"/home/kyle/{dot}"), dry_run=dry_run)

    # 8. Restore SSH credentials metadata
    logging.info("Step 8: Restoring SSH metadata...")
    ssh_files = ["config", "authorized_keys", "id_ed25519.pub"]
    for ssh_file in ssh_files:
        restore_files(backup_dir / "ssh" / ssh_file, Path(f"/home/kyle/.ssh/{ssh_file}"), dry_run=dry_run)
    
    if not dry_run:
        ssh_dir = Path("/home/kyle/.ssh")
        if ssh_dir.exists():
            ssh_dir.chmod(0o700)
            for item in ssh_dir.iterdir():
                item.chmod(0o600)

    # 9. Restore API keys and configurations
    logging.info("Step 9: Restoring agent configurations...")
    restore_files(backup_dir / "configs" / "agy-settings.json", Path("/home/kyle/.gemini/antigravity-cli/settings.json"), dry_run=dry_run)
    restore_files(backup_dir / "configs" / "claude-settings.json", Path("/home/kyle/.claude/settings.json"), dry_run=dry_run)
    restore_files(backup_dir / "configs" / "claude" / ".credentials.json", Path("/home/kyle/.claude/.credentials.json"), dry_run=dry_run)
    restore_files(backup_dir / "configs" / "claude" / "settings.local.json", Path("/home/kyle/.claude/settings.local.json"), dry_run=dry_run)
    restore_files(backup_dir / "configs" / "gemini", Path("/home/kyle/.gemini"), dry_run=dry_run, is_dir=True)
    restore_files(backup_dir / "configs" / "agentic-memory-compiler.env", Path("/home/kyle/dev/agentic-memory-compiler/.env"), dry_run=dry_run)

    # Restore Syncthing configs
    restore_files(backup_dir / "configs" / "syncthing", Path("/home/kyle/.local/state/syncthing"), dry_run=dry_run, is_dir=True)

    # 10. Restore Docker volumes
    logging.info("Step 10: Restoring Docker volumes...")
    volumes_dir = backup_dir / "docker-volumes"
    if volumes_dir.exists():
        pgdata_tar = volumes_dir / "onecli_pgdata.tar.gz"
        appdata_tar = volumes_dir / "onecli_app-data.tar.gz"
        
        if pgdata_tar.exists() and not dry_run:
            logging.info("Restoring pgdata volume...")
            run_cmd(["docker", "volume", "create", "onecli_pgdata"])
            run_cmd([
                "docker", "run", "--rm", "-v", "onecli_pgdata:/volume", "-v", f"{volumes_dir}:/backup",
                "alpine", "sh", "-c", "tar xzf /backup/onecli_pgdata.tar.gz -C /volume"
            ])
            
        if appdata_tar.exists() and not dry_run:
            logging.info("Restoring app-data volume...")
            run_cmd(["docker", "volume", "create", "onecli_app-data"])
            run_cmd([
                "docker", "run", "--rm", "-v", "onecli_app-data:/volume", "-v", f"{volumes_dir}:/backup",
                "alpine", "sh", "-c", "tar xzf /backup/onecli_app-data.tar.gz -C /volume"
            ])

    # 11. Restore Obsidian vault seed
    logging.info("Step 11: Seeding Obsidian Vault...")
    restore_files(backup_dir / "obsidian-vault", Path("/home/kyle/Documents/obsidian"), dry_run=dry_run, is_dir=True)

    # 12. Restart systemd services
    logging.info("Step 12: Restarting services...")
    manage_systemd_service("shiny-server.service", "start", user=False, dry_run=dry_run)
    manage_systemd_service("geminios.service", "start", user=True, dry_run=dry_run)
    manage_systemd_service("milton.service", "start", user=True, dry_run=dry_run)

    logging.info("=== nixPi5 Restoration Complete! ===")
    logging.info("Manual actions remaining:")
    logging.info("1. Set Samba passwords: 'sudo smbpasswd -a kyle'")
    logging.info("2. Restore private SSH keys in ~/.ssh/id_ed25519 (not backed up for security)")


def restore_nixMitters(backup_dir: Path, dry_run: bool = False) -> None:
    """Execute hardened restoration steps for nixMitters workstation."""
    logging.info("=== Commencing nixMitters Restoration ===")

    # Workstation config restoration targets kyle configs
    # 1. Restore dotfiles
    logging.info("Step 1: Restoring user config dotfiles...")
    dotfiles = [".bashrc", ".bash_profile", ".bash_aliases", ".gitconfig", ".Rprofile", ".Renviron"]
    for dot in dotfiles:
        restore_files(backup_dir / "dotfiles" / dot, Path(f"/home/kyle/{dot}"), dry_run=dry_run)

    # 2. Restore SSH metadata
    logging.info("Step 2: Restoring SSH metadata...")
    ssh_files = ["config", "authorized_keys", "id_ed25519.pub"]
    for ssh_file in ssh_files:
        restore_files(backup_dir / "ssh" / ssh_file, Path(f"/home/kyle/.ssh/{ssh_file}"), dry_run=dry_run)
    
    if not dry_run:
        ssh_dir = Path("/home/kyle/.ssh")
        if ssh_dir.exists():
            ssh_dir.chmod(0o700)
            for item in ssh_dir.iterdir():
                item.chmod(0o600)

    # 3. Restore agent settings
    logging.info("Step 3: Restoring agent settings templates...")
    restore_files(backup_dir / "configs" / "agy-settings.json", Path("/home/kyle/.gemini/antigravity-cli/settings.json"), dry_run=dry_run)
    restore_files(backup_dir / "configs" / "claude-settings.json", Path("/home/kyle/.claude/settings.json"), dry_run=dry_run)

    # 4. Restore Syncthing config templates
    logging.info("Step 4: Restoring Syncthing configs...")
    restore_files(backup_dir / "configs" / "syncthing", Path("/home/kyle/.config/syncthing"), dry_run=dry_run, is_dir=True)

    logging.info("=== nixMitters Restoration Complete! ===")
    logging.info("Manual actions remaining:")
    logging.info("1. Restore private SSH keys in ~/.ssh/id_ed25519 (not backed up for security)")


def main() -> None:
    check_root()

    parser = argparse.ArgumentParser(description="Fleet configuration and database restoration script.")
    parser.add_argument("--host", choices=["nixPi5", "nixMitters"], required=True, help="Target host profile to restore.")
    parser.add_argument("--backup-dir", required=True, help="Path to the backup source directory.")
    parser.add_argument("--dry-run", action="store_true", help="Preview copy and service state changes without committing them.")
    args = parser.parse_args()

    backup_path = Path(args.backup_dir)
    if not backup_path.exists():
        logging.error("Backup source directory not found: %s", args.backup_dir)
        sys.exit(1)

    if args.host == "nixPi5":
        restore_nixPi5(backup_path, dry_run=args.dry_run)
    elif args.host == "nixMitters":
        restore_nixMitters(backup_path, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
