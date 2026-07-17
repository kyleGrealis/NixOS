---
name: nixos-user-configs
description: Guidelines for managing user application configurations using Home Manager out-of-store symlinks on NixOS.
---

# NixOS User Configs

This skill outlines how to manage desktop application configurations (such as Positron settings, terminal settings, editor preferences, and system monitors) within a NixOS system repository while maintaining the ability for local applications to write changes directly to those files.

---

## 1. Out-of-Store Symlinks (Mutable Configs)

To keep application configuration files mutable by their respective programs (avoiding read-only errors when settings are saved in the GUI), use Home Manager's `config.lib.file.mkOutOfStoreSymlink`.

### Migration Steps:
1. Create a subdirectory under your user configurations directory in the repository:
   ```bash
   mkdir -p ~/NixOS/users/kyle/configs/<app_name>
   ```
2. Move the active file from `~/.config` into the new repository path:
   ```bash
   mv ~/.config/<app_name>/<filename> ~/NixOS/users/kyle/configs/<app_name>/<filename>
   ```
3. Map the target location in `users/kyle/home.nix` to reference the file in the repository path:
   ```nix
   home.file.".config/<app_name>/<filename>".source =
     config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/<app_name>/<filename>";
   ```
4. Rebuild the system to link the paths:
   ```bash
   nixos-rebuild switch --flake .#nixMitters
   ```

---

## 2. Declarative Config Blocks (Immutable Configs)

For system parameters, user directories, MIME bindings, or configurations that should remain entirely static, define them inline within your Nix expressions rather than tracking configuration files.

* **Default applications / MIME mapping:** Use `xdg.mimeApps.defaultApplications`.
* **XDG base directory locations:** Use `xdg.userDirs`.
* **Global Git Ignores:** Use `programs.git.ignores` rather than an excludes file.

---

## 3. NixOS MCP Server Configuration

When configuring or debugging Model Context Protocol (MCP) servers on NixOS platforms (e.g., `nixMitters` or `pi5`), follow these rules to prevent FHS dynamic linking crashes and executable lookup failures:

### Avoid `uvx` or `npx`
Standard Node/Python tools running via `uvx` or `npx` fetch pre-compiled binaries that expect FHS libraries (like `/lib64/ld-linux-x86-64.so.2`) and will crash on startup under NixOS.

### Use Nix-Native Run Commands
Instead of raw packages, use `nix run` via the absolute path of the Nix package manager:
* **Command:** `/run/current-system/sw/bin/nix`
* **Arguments:** `["run", "github:org/repo", "--"]`

### Expose Nix PATH in Env
The background execution daemon runs in a highly restricted shell environment. You must explicitly declare the Nix paths in the `env` block of the server configuration:
```json
"env": {
  "PATH": "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
}
```

### Configuration Templates
Ensure both `/home/kyle/.gemini/antigravity-cli/mcp_config.json` and `/home/kyle/.gemini/antigravity-cli/settings.json` carry the corrected Nix execution paths.

Example `mcp_config.json` entry:
```json
"nixos": {
  "command": "/run/current-system/sw/bin/nix",
  "args": ["run", "github:utensils/mcp-nixos", "--"],
  "env": {
    "PATH": "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
  }
}
```

---

## 4. Home Manager Activation Conflicts
When activating Home Manager on a fresh or restored user environment (via `nixos-rebuild switch`), the activation service will fail if it detects existing dotfiles (e.g. `~/.bashrc` or `~/.bash_profile`) that would be overwritten by managed symlinks.

### The Solution:
Do NOT permanently set `home-manager.backupFileExtension` in the configuration files, as this creates unwanted `.backup` files in the home directory. Instead, manually move or delete the conflicting files out of the way (using `trash-put` to clean them up) before running the activation.

---

## 5. Running Generic Pre-Compiled Binaries (nix-ld)
NixOS does not possess a standard Filesystem Hierarchy Standard (FHS) layout. Pre-compiled binaries downloaded from external sources (such as the `agy` CLI installer or standard node/python helper binaries) will fail immediately on execution because they cannot find the standard dynamic linker path (e.g., `/lib/ld-linux-aarch64.so.1` or `/lib64/ld-linux-x86-64.so.2`).

### The Solution:
Enable `nix-ld` system-wide in `configuration.nix`:
```nix
programs.nix-ld.enable = true;
```
This dynamically hooks the system's dynamic loader, redirecting lookups to appropriate Nix store libraries and allowing generic ELF binaries to run natively out of the box.

---

## 6. Restoring Broken settings.json Symlinks
Accepting CLI workspace trust prompts or CLI setting writes can cause the local agent to overwrite declarative `settings.json` symlinks with physical files. When this occurs, Syncthing may propagate the physical files across the fleet.

### The Solution:
1. **Deduplicate & Exclude:** Add `settings.json` and `settings.local.json` to both `.gemini/.stignore` and `.claude/.stignore` on all machines to prevent Syncthing from syncing these files, ensuring Home Manager has sole authority.
2. **Re-link via Activation:** Trash the overwritten physical files:
   ```bash
   trash-put ~/.gemini/antigravity-cli/settings.json
   ```
3. **Trigger Re-linking:** Restart the system-wide activation service (which runs as root) to force Home Manager to re-evaluate and recreate the out-of-store symlinks:
   ```bash
   sudo systemctl restart home-manager-kyle.service
   ```

---

## 7. Version Mismatches in Home Manager Modules (e.g., programs.ssh.settings)
When managing configurations across a fleet running different channel versions (e.g. `nixMitters` on unstable `26.11` vs `piMitters` on stable `25.11`), syntax extensions added in newer Home Manager releases will cause hard evaluation failures on older systems.

### The Problem:
Using `programs.ssh.settings` resolves deprecation warnings on the unstable channel but triggers a hard `The option does not exist` evaluation failure on stable channels where only `programs.ssh.matchBlocks` is supported.

### The Solution:
Revert the configuration to the older, universally supported syntax (`programs.ssh.matchBlocks`) to preserve fleet-wide build compatibility until all hosts are upgraded to the same channel version. Allow the deprecation warning to persist on newer systems to ensure build success on older ones.

---

## 8. Initializing NixOS WSL (`wslNixMitters`)
When setting up a new NixOS WSL instance (`wslNixMitters`) on a Windows host, the instance runs a minimal configuration out of the box. 

### The Solution:
1. Boot into the WSL instance and clone your system repository:
   ```bash
   git clone https://github.com/kyleGrealis/NixOS.git ~/NixOS
   ```
2. Activate your declarative workstation profile:
   ```bash
   git add -A # Ensure all untracked files are visible to Nix
   sudo nixos-rebuild switch --flake ~/NixOS#wslNixMitters
   ```

---

## 9. WSL Backup Integration & Syncthing Parity
WSL nodes run in a guest network namespace and lack bare-metal systemd timer context. They also share workspace directory paths with the Windows host, creating sync-state edge cases.

### Work Secrets & Dev Backups
* **WSL Backup Utility**: Expose host-specific backup scripts (like `backup-wslNixMitters` for secrets, `backup-wsl-dev` for WSL workspaces, and `backup-win-dev` for Windows folders) as system-wide packages via `pkgs.writeShellApplication` in [hosts/wslNixMitters/configuration.nix](file:///home/kyle/NixOS/hosts/wslNixMitters/configuration.nix).
* **Parity & Naming**: Do not use generic script names (like `backup-dev`). Use `backup-wsl-dev` to distinguish it from bare-metal server/laptop backups.

### Resolving Syncthing Sync Stalls (2% Completion Issue)
When sharing compiler workspaces or active repositories between WSL and host machines, mismatched ignore patterns cause Syncthing to stall (often around 2% completion), as one host expects git objects or virtual environments that another host ignores.
* **The Solution**: Maintain identical `.stignore` configuration lists (e.g. ignoring `.git`, `.venv`, and `node_modules`) on both the WSL guest path (`/home/kyle/dev/...`) and the Windows host path (`C:\Users\kxg679\Documents\dev\...`). Scan state must be manually triggered (`curl -X POST http://127.0.0.1:8384/rest/db/scan?folder=<id>`) after aligning patterns.


---

## 10. Nix Script Packaging Constraints (writeShellApplication)
When packaging shell scripts in Nix configurations using `pkgs.writeShellApplication` or `pkgs.writeScriptBin`, Nix automatically compiles the script and runs ShellCheck validation as part of the builder phase.

* **No Emojis/Special Characters**: Avoid using UTF-8 emojis or non-standard characters in script strings, as the default Nix build environment cannot encode them and will crash the derivation build.
* **Avoid ShellCheck Violations**:
  * Do not use indirect exit status checks (`if [ $? -eq 0 ]`). Check exit status directly (`if command; then`) or store in variables correctly.
  * Quote expansions inside pattern substitutions separately (e.g., use `${var#"$pattern_var"}` instead of `${var#$pattern_var}`).
