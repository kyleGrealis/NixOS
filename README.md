# NixOS Multi-Host System Configurations

This repository contains the unified, declarative NixOS and Home Manager configurations for the multi-machine fleet:
*   **`nixMitters` (Laptop Workstation):** Runs `nixos-unstable` for rolling packages, NVIDIA drivers, GNOME desktop environment, and interactive data science development.
*   **`nixPi5` (Raspberry Pi 5 Server):** Runs `nixos-25.11` (Stable) for hosting production bots (`geminiOS`, `milton`), Shiny Server, RevealJS static slides, and GitHub Actions self-hosted runners.

---

## 🗄️ Repository Structure

The configuration is structured modularly to separate system-level hosts, user environments, and package overlays:

```text
/home/kyle/NixOS/
├── flake.nix                  # Root flake defining all hosts, inputs, and pins
├── hosts/
│   ├── nixMitters/            # Laptop workstation host configuration
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── pi5/                   # Headless Raspberry Pi 5 server configuration
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── r-env.nix          # Production R packages definition
├── pkgs/
│   └── google-sans.nix        # System-wide package overlays
└── users/
    └── kyle/
        ├── home.nix           # Base/shared Home Manager configuration
        ├── nixMitters.nix     # nixMitters-specific user packages & GUI setups
        └── pi5.nix            # pi5-specific user packages & systemd timers/services
```

---

## ❄️ How It Works: Multi-Host & Multi-Channel

To support different stability needs across machines, this repository tracks two distinct Nixpkgs streams:
1.  **Laptop (`nixMitters`):** Uses the rolling `nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"` and unstable `home-manager` inputs. This guarantees the latest kernels, desktop updates, and applications.
2.  **Server (`pi5`):** Uses the stable `release-25.11` Home Manager branch following the `nixos-raspberrypi` hardware wrapper pin. This ensures server predictability, stable kernel module building, and dependency stability.

Both configurations reside in the root [flake.nix](file:///home/kyle/NixOS/flake.nix), referencing their respective target architectures and package channels.

---

## 🧪 R Development: Laptop vs. Server

The R runtime is split between interactive workstation development and headless server production:

### Laptop Workstation (`nixMitters`)
*   **Interactive Workspace:** Initiated dynamically by entering `~/dev/`. `direnv` evaluates the folder's local `flake.nix` (honoring Git-tracked files via the Git-tracked copy trick to eliminate loading lag).
*   **Writability:** Bypasses read-only Nix store constraints by exporting a user-writable library directory (`.Rlibs`), allowing interactive packages to compile alongside Nix-provided base packages.
*   **Editor Integration:** Positron targets the Ark launcher wrapper hack at `~/dev/.Rbin/bin/R` to resolve package loading paths.

### Server (`nixPi5`)
*   **Production Services:** The system configuration compiles a unified `rEnv` defined in [hosts/pi5/r-env.nix](file:///home/kyle/NixOS/hosts/pi5/r-env.nix).
*   **Isolation:** The compiled package environment is bound directly to systemd environment variables for `shiny-server` and injected into the native GitHub Actions runner extra packages, ensuring fully isolated, headless execution of deployments without user environments.
*   **CLI Testing:** Added to `environment.systemPackages` so calling `R` or `Rscript` from the SSH shell maps to the exact same packages.

---

## 💿 Raspberry Pi 5: Flashing & Bootstrap Instructions

The build, flashing, login, hardware profile generation, and backup/restore guidelines for the Raspberry Pi 5 server are documented in the local file:
*   [pi5-bootstrap.md](file:///home/kyle/NixOS/pi5-bootstrap.md) (This file is ignored by Git and not committed to the repository).

---

## 🩺 System Rebuilds and Verification

Apply updates or rebuild system changes on either machine:
```bash
# On Laptop (or use the 'nix-switch' alias)
sudo nixos-rebuild switch --flake ~/NixOS#nixMitters

# On Raspberry Pi 5 (or use the 'nix-switch' alias)
sudo nixos-rebuild switch --flake ~/NixOS#pi5
```

Verify service statuses:
```bash
tailscale status
docker ps
systemctl status nginx
systemctl status shiny-server
systemctl --user status geminios milton
```

---

## 🔄 System Maintenance & Updates

Use these workflows to keep system packages, R environments, and NixOS inputs up to date.

### 1. Adding, Removing, or Modifying Packages
*   **System-wide Packages:** Edit `environment.systemPackages` in the host's `configuration.nix` (e.g., [hosts/nixMitters/configuration.nix](file:///home/kyle/NixOS/hosts/nixMitters/configuration.nix) or [hosts/pi5/configuration.nix](file:///home/kyle/NixOS/hosts/pi5/configuration.nix)).
*   **User/Home Manager Packages:** Edit `home.packages` in the base [users/kyle/home.nix](file:///home/kyle/NixOS/users/kyle/home.nix), or host-specific user config [users/kyle/nixMitters.nix](file:///home/kyle/NixOS/users/kyle/nixMitters.nix) / [users/kyle/pi5.nix](file:///home/kyle/NixOS/users/kyle/pi5.nix).
*   **Applying Changes:** Run the rebuild command: `sudo nixos-rebuild switch --flake ~/NixOS#<host>`.

### 2. Updating R Packages
R package management differs between the laptop workstation and the production server:
*   **Production Server (`pi5`):**
    1. Open [hosts/pi5/r-env.nix](file:///home/kyle/NixOS/hosts/pi5/r-env.nix).
    2. Add or remove packages from the `packages` list (must be valid Nixpkgs R packages, e.g., `dplyr`, `ggplot2`).
    3. Rebuild the system: `sudo nixos-rebuild switch --flake ~/NixOS#pi5`.
*   **Laptop Workstation (`nixMitters`):**
    *   Laptop R environments are project-specific to keep the system clean and build times fast.
    *   Enter the project directory (e.g., `~/dev/some-project`). `direnv` will load the local `flake.nix`.
    *   Install/update packages interactively in R using `install.packages()`. They will be compiled into the local `.Rlibs` directory within that project.

### 3. Upgrading Packages & Lockfile (Flake Inputs)
To update existing packages to their latest versions matching upstream Nixpkgs channels (stable/unstable):
1. Navigate to the NixOS directory:
   ```bash
   cd ~/NixOS
   ```
2. Update the inputs:
   *   **Update Everything:** `nix flake update`
   *   **Update a Specific Input (e.g., nixpkgs):** `nix flake update nixpkgs`
3. Rebuild and switch:
   ```bash
   sudo nixos-rebuild switch --flake ~/NixOS#<host>
   ```

### 4. Performing Major NixOS Upgrades
When a new NixOS stable branch is released (e.g., upgrading `release-25.11` to `release-26.05` on `pi5`):
1. Open [flake.nix](file:///home/kyle/NixOS/flake.nix).
2. Locate the stable channel URL inputs and bump the version tag (e.g., change `/release-25.11` to `/release-26.05`).
3. Update the inputs lockfile: `nix flake update`.
4. Rebuild the system: `sudo nixos-rebuild switch --flake ~/NixOS#pi5`.
   > [!IMPORTANT]
   > Keep `system.stateVersion` unchanged (e.g., `"25.11"` or `"26.05"`) in the host configurations. This value represents the release version of the original installation and is used to maintain compatibility for stateful services (like database directories or system layouts). Upgrading it can break backward compatibility.
