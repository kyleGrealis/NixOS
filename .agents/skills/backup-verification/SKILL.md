---
name: backup-verification
description: Verify, test, and audit backup status and cloud sync for nixMitters and nixPi5.
disable-model-invocation: true
allowed-tools: run_command
---

# Backup Verification Operations

Guidelines for verifying, executing, and auditing system backups.

## Safety Constraints
- **CRITICAL:** Never touch `/var/lib/shiny-data/sofia/sofia.sqlite` directly. All operations must proceed on backup copies.
- **CRITICAL:** Ask for explicit confirmation before database mutations.

## Manual Executions

### 1. Trigger Full Server Backup
Manually run the daily backup and cloud sync script:
```bash
systemctl --user start backup-nixPi5
```
Or run the script directly to see inline output:
```bash
/home/kyle/NixOS/scripts/backup-nixPi5.sh
```

### 2. Trigger Sofia DB Backup
```bash
systemctl --user start backup-sofia-q2h
```

### 3. Trigger Laptop Backup
```bash
systemctl --user start backup-nixMitters
```

## Verification & Auditing
- Check the log files: `/home/kyle/backup-nixPi5.log`.
- Verify SQLite online `.backup` copies:
  ```bash
  ls -lh /mnt/piCloud/pi5-backup/sqlite-backups/
  ```
- Validate `rclone` cloud status:
  ```bash
  rclone lsd gdrive:systems-backups
  ```
