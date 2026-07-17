---
name: nixos-rebuild-ops
description: Rebuild, test, and switch NixOS configurations for nixMitters and piMitters.
disable-model-invocation: true
allowed-tools: run_command
---

# NixOS Rebuild Operations

This skill provides step-by-step instructions for testing and activating NixOS configuration changes.

## Commands

### 1. Interactive Testing (Recommended)
Before making configuration changes permanent, use the `test` command. This builds and activates the configuration in memory without adding a permanent entry to the bootloader menu.
```bash
# On Laptop (nixMitters)
sudo nixos-rebuild test --flake ~/NixOS#nixMitters

# On Raspberry Pi 5 (piMitters)
sudo nixos-rebuild test --flake ~/NixOS#piMitters
```
*Benefits:* Avoids boot menu bloat; simple reboot rollbacks if the configuration breaks something.

### 2. Switching (Permanent Activation)
Once changes are verified and stable, activate them permanently:
```bash
# On Laptop (nixMitters)
sudo nixos-rebuild switch --flake ~/NixOS#nixMitters

# On Raspberry Pi 5 (piMitters)
sudo nixos-rebuild switch --flake ~/NixOS#piMitters
```

### 3. Flake Updates
To update Nix flake inputs:
```bash
cd ~/NixOS
nix flake update
```

## Safety Checklist
- Always use `test` first for hardware configuration or system services adjustments.
- Do NOT change `system.stateVersion` when upgrading NixOS releases.
- Ensure that the repository changes are committed or tracked by Git so that Nix can resolve files.
