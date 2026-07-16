{ config, pkgs, ... }:

let
  rEnv = pkgs.rEnv or (import ./r-env.nix { inherit pkgs; });
in
{
  imports = [
    # Include the hardware scan results (will be generated on the Pi5 itself during install)
    ./hardware-configuration.nix
  ];

  # Bootloader is managed by nixos-raspberrypi flake
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = pkgs.lib.mkForce false;

  networking.hostName = "nixPi5";
  networking.networkmanager.enable = true;

  # Static IP configuration for home network
  networking.interfaces.end0.useDHCP = false;
  networking.interfaces.end0.ipv4.addresses = [{
    address = "192.168.1.11";
    prefixLength = 24;
  }];
  networking.defaultGateway = "192.168.1.254";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # Open system ports for administration, app servers, and Syncthing
  networking.firewall = {
    enable = true;
    # 22      OpenSSH
    # 3838    Shiny server
    # 3839    Nginx (slides server)
    # 8384    Syncthing Web UI
    # 22000   Syncthing Sync
    # 21027   Syncthing Discovery
    allowedTCPPorts = [ 22 3838 3839 22000 8384 ];
    allowedUDPPorts = [ 22000 21027 ];
    trustedInterfaces = [ "tailscale0" ];
  };

  # Set your time zone
  time.timeZone = "America/Chicago";

  # Select internationalisation properties
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure console keymap
  console.keyMap = "us";

  # Define kyle user to match existing permissions (UID/GID 1002)
  users.users.kyle = {
    isNormalUser = true;
    uid = 1002;
    extraGroups = [ "wheel" "docker" ];
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMwrY1D7g4guY3lk4qQK9Rnl5VjcswFp7SV03q+SV9RA kyle@archMitters"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA7UaxUw6EhjwNS1jkkLT7lHwfN83vRt1vFeQ6/wi+o8 github-actions-deploy"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ+0dyU90SzuT20Ct3hoO/Ai2QGSifIJdxsk5MGXLKs6 pi4"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAChITz8p8XYrcjlp1SS4ufp6f/QnL8FMKg1rdIvJ5Zj github-work-wsl"
    ];
  };

  users.groups.kyle = {
    gid = 1002;
  };

  # Passwordless Sudo for wheel group members
  security.sudo.wheelNeedsPassword = false;

  # File system mounts (Samsung T9 exFAT external SSD)
  fileSystems."/mnt/piCloud" = {
    device = "/dev/disk/by-uuid/767C-0994";
    fsType = "exfat";
    options = [
      "defaults"
      "uid=1002"
      "gid=1002"
      "fmask=0022"
      "dmask=0022"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # Enable OpenSSH daemon (crucial for headless management!)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true; # Allow password initially for bootstrapping
    };
  };

  # Enable Tailscale and enable packet forwarding for exit-node routing
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # Declarative one-shot service to enforce exit-node flag on boot
  systemd.services.tailscale-exit-node = {
    description = "Enforce Tailscale exit-node advertisement";
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "tailscaled.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.tailscale}/bin/tailscale up --advertise-exit-node";
      RemainAfterExit = true;
    };
  };

  # Enable Docker
  virtualisation.docker.enable = true;

  # Declarative Cloudflare Tunnel configuration
  services.cloudflared = {
    enable = true;
    tunnels = {
      "b76baf87-cb41-4c3e-98fd-27b806a38569" = {
        credentialsFile = "/var/lib/cloudflare-tunnels/b76baf87-cb41-4c3e-98fd-27b806a38569.json";
        default = "http_status:404";
        ingress = {
          "shiny.kylegrealis.com" = "http://localhost:3838";
          "slides.kylegrealis.com" = "http://localhost:3839";
          "ssh.kylegrealis.com" = "ssh://localhost:22";
          "projects.kylegrealis.com" = "http://localhost:3890";
        };
      };
    };
  };

  # Nginx server for RevealJS slides (replaces node-serve on port 3839)
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      listen = [ { addr = "0.0.0.0"; port = 3839; } ];
      locations."/" = {
        root = "/srv/slides";
      };
    };
  };

  # Native Systemd service for RStudio Shiny Server
  systemd.services.shiny-server = {
    description = "Shiny Server";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    
    environment = {
      R_HOME = "${rEnv}/lib/R";
      PATH = pkgs.lib.mkForce "${rEnv}/bin:${pkgs.nodejs_20}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin";
      SOFIA_DB_PATH = "/var/lib/shiny-data/sofia/sofia.sqlite";
      R_PROFILE_USER = "/dev/null";
    };

    serviceConfig = {
      Type = "simple";
      User = "kyle";
      Group = "kyle";
      WorkingDirectory = "/srv/shiny-server";
      ExecStart = "${pkgs.nodejs_20}/bin/node /srv/shiny-server/lib/main.js /etc/shiny-server/shiny-server.conf";
      Restart = "always";
      RestartSec = "10s";
      # Create logging and state directories if they don't exist
      LogsDirectory = "shiny-server";
      LogsDirectoryMode = "0755";
      StateDirectory = "shiny-server";
      StateDirectoryMode = "0755";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Declarative Shiny Server configuration file
  environment.etc."shiny-server/shiny-server.conf".text = ''
    # /etc/shiny-server/shiny-server.conf

    # Instruct Shiny Server to run applications as the user "kyle"
    run_as kyle;

    # Stay on forever
    app_idle_timeout 0;

    # Define a server that listens on port 3838
    server {
      listen 3838;

      # Define a location at the base URL
      location / {
        # Host the directory of Shiny Apps stored in this directory
        site_dir /srv/shiny-server;

        # Log all Shiny output to files in this directory
        log_dir /var/log/shiny-server;

        # When a user visits the base URL rather than a particular application,
        # an index of the applications available in this directory will be shown.
        directory_index on;
      }
    }
  '';

  # Native Declarative GitHub Actions Runners (auto-wrapped and patched for NixOS ELF binaries)
  services.github-runners = {
    baby-tracker = {
      enable = true;
      url = "https://github.com/kyleGrealis/baby-tracker";
      tokenFile = "/var/lib/github-runners/baby-tracker.token";
      user = "kyle";
      workDir = "/var/lib/github-runners/baby-tracker";
      extraPackages = with pkgs; [
        git
        curl
        nodejs_24
        rEnv
        systemd
        sudo
        coreutils
      ];
    };
    r2-dashboard = {
      enable = true;
      url = "https://github.com/kyleGrealis/r2-dashboard";
      tokenFile = "/var/lib/github-runners/r2-dashboard.token";
      user = "kyle";
      workDir = "/var/lib/github-runners/r2-dashboard";
      extraPackages = with pkgs; [
        git
        curl
        nodejs_24
        rEnv
        systemd
        sudo
        coreutils
      ];
    };
    sofia = {
      enable = true;
      url = "https://github.com/kyleGrealis/sofia";
      tokenFile = "/var/lib/github-runners/sofia.token";
      user = "kyle";
      workDir = "/var/lib/github-runners/sofia";
      extraPackages = with pkgs; [
        git
        curl
        nodejs_24
        rEnv
        systemd
        sudo
        coreutils
      ];
    };
  };

  # System-wide packages
  environment.systemPackages = with pkgs; [
    git
    micro
    btop
    rsync
    rclone
    sqlite
    nodejs_24
    pnpm
    git-lfs
    gcc
    gnumake
    python3
    rEnv
  ];

  # Enable all terminfo packages (including Ghostty, Alacritty, Kitty, etc.) system-wide
  environment.enableAllTerminfo = true;

  # Enable nix-ld to run generic pre-compiled dynamically linked binaries
  programs.nix-ld.enable = true;

  # Allow unfree packages (needed for cloudflared, etc.)
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "docker-28.5.2"
  ];

  # Nix Settings (Enable Flakes and Optimize Store)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  services.syncthing = {
    enable = true;
    user = "kyle";
    dataDir = "/home/kyle";
    configDir = "/home/kyle/.local/state/syncthing";
    guiAddress = "0.0.0.0:8384"; # Restrict access via Tailscale/UFW firewall
    openDefaultPorts = true;
    overrideDevices = true;
    overrideFolders = true;
    extraFlags = [
      "--allow-newer-config"
    ];
    settings = {
      devices = {
        "nixMitters" = { id = "4M2NBJI-EZDAG3P-5UFM3AM-YWBX3E3-T6CNBYM-O6QLNKM-7QYEYXD-MFAY2AM"; };
        "nixPi5" = { id = "HR7M54M-7UPVYDD-UNJUJAJ-QH4QOZI-UHV6HM4-HW66Z7A-D7KAPXO-LGZYCA5"; };
        "windowsMitters" = { id = "PFYTBDZ-PLXFXTJ-UGOIKCR-RR3LZZB-4BQBNSH-QZWOGFR-AFWZ2QP-3GRRRAP"; };
        "UH-JCX0TV3" = { id = "52ZVBSB-QSFLLK3-MWYTJF5-QQIFTFG-MQWJGRE-IBXO6TA-WLLU57F-U57Y4QZ"; };
      };
      folders = {
        "claude-home" = {
          path = "/home/kyle/.claude";
          devices = [ "nixMitters" "UH-JCX0TV3" ];
          ignorePerms = true;
        };
        "gemini-cli" = {
          path = "/home/kyle/.gemini";
          devices = [ "nixMitters" "UH-JCX0TV3" ];
          ignorePerms = true;
        };
        "kyle-claude-projects" = {
          path = "/home/kyle/.claude/projects";
          devices = [ "nixMitters" "UH-JCX0TV3" ];
          ignorePerms = true;
        };
        "kyle-compiler" = {
          path = "/home/kyle/dev/agentic-memory-compiler";
          devices = [ "nixMitters" "windowsMitters" ];
          ignorePerms = true;
        };
        "ukczc-orzsn" = {
          path = "/home/kyle/Documents/obsidian";
          devices = [ "nixMitters" "windowsMitters" ];
          ignorePerms = true;
        };
      };
    };
  };

  system.stateVersion = "25.11";

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "Pi5";
        "security" = "user";
        "map to guest" = "never";
      };
      piCloud = {
        path = "/mnt/piCloud";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0644";
        "directory mask" = "0755";
        "valid users" = "kyle";
      };
    };
  };
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
}
