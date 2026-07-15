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
# On Laptop
sudo nixos-rebuild switch --flake ~/NixOS#nixMitters

# On Raspberry Pi 5
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
