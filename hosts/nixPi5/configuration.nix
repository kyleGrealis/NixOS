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
      PATH = pkgs.lib.mkForce "${rEnv}/bin:${pkgs.nodejs_22}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin";
      SOFIA_DB_PATH = "/var/lib/shiny-data/sofia/sofia.sqlite";
    };

    serviceConfig = {
      Type = "simple";
      User = "kyle";
      Group = "kyle";
      WorkingDirectory = "/srv/shiny-server";
      ExecStart = "${pkgs.nodejs_22}/bin/node /srv/shiny-server/node_modules/shiny-server/lib/main.js /etc/shiny-server/shiny-server.conf";
      Restart = "always";
      RestartSec = "10s";
      # Create logging directory if it doesn't exist
      LogsDirectory = "shiny-server";
      LogsDirectoryMode = "0755";
      StandardOutput = "append:/var/log/shiny-server/shiny-server.log";
      StandardError = "append:/var/log/shiny-server/shiny-server.log";
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
        nodejs_22
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
        nodejs_22
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
        nodejs_22
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
    nodejs_22
    git-lfs
    gcc
    gnumake
    python3
    rEnv
  ];

  # Allow unfree packages (needed for cloudflared, etc.)
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "docker-28.5.2"
  ];

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
