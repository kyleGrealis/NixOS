---
name: nix-pi5-service-ops
description: Inspect, diagnose, and manage systemd user services running on nixPi5.
disable-model-invocation: true
allowed-tools: run_command
---

# Headless Pi5 Service Operations

This skill details diagnostic procedures for systemd user-level daemons on `nixPi5` (e.g., `geminios`, `milton`, timers).

## Diagnostics Checklist

### 1. View Service Status
Check the status of the user-level daemon:
```bash
systemctl --user status geminios
systemctl --user status milton
```

### 2. Inspect Running Logs
View the last 100 log lines with active updates:
```bash
journalctl --user -n 100 -u geminios -f
journalctl --user -n 100 -u milton -f
```

### 3. Restart Service
Restart a service safely if it hangs or after an update:
```bash
systemctl --user restart geminios
```

## Sandboxing Rails
Services like `geminios` use systemd sandboxing. When debugging file access errors:
- **Write Paths:** Configured via `BindPaths`. Ensure files reside within allowed paths:
  - `/home/kyle/geminiOS`
  - `/home/kyle/.gemini/state`
  - `/home/kyle/.gemini/tmp/kyle`
  - `/home/kyle/Documents/obsidian/dev/geminiOS/QwertyMemory`
- **Read-Only Paths:** Configured via `BindReadOnlyPaths`.
- **System Constraints:** `ProtectHome = "tmpfs"` hides other home directories unless explicitly bound.
