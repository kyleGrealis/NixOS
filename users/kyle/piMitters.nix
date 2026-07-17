{ config, pkgs, ... }:

let
  backup-piMitters-pkg = pkgs.writeShellApplication {
    name = "backup-piMitters";
    runtimeInputs = [
      pkgs.rsync
      pkgs.sqlite
      pkgs.rclone
      pkgs.docker
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.findutils
    ];
    text = builtins.readFile ../../scripts/backup-piMitters.sh;
  };

  backup-sofia-q2h-pkg = pkgs.writeShellApplication {
    name = "backup-sofia-q2h";
    runtimeInputs = [
      pkgs.sqlite
      pkgs.rclone
      pkgs.coreutils
      pkgs.findutils
    ];
    text = builtins.readFile ../../scripts/backup-sofia-q2h.sh;
  };

  get-carried-over-tasks-pkg = pkgs.writers.writePython3Bin "get-carried-over-tasks" { } (builtins.readFile ../../scripts/get-carried-over-tasks.py);
in
{
  imports = [
    ./home.nix
  ];

  home.stateVersion = "25.11";

  # pi5-specific user packages
  home.packages = with pkgs; [
    uv               # Fast Python packaging (needed for memory compilers)
    btop             # System monitor
    delta            # Git diff tool
    pnpm             # Fast Node.js package manager
    
    # Declarative user utilities
    backup-piMitters-pkg
    backup-sofia-q2h-pkg
    get-carried-over-tasks-pkg
  ];

  programs.bash.shellAliases = {
    # Headless/server-specific aliases
    copy = "tee >(osc-copy)";
    nix-switch = "sudo nixos-rebuild switch --flake ~/NixOS#piMitters";
  };

  programs.bash.initExtra = ''
    # OSC 52 copy helper for headless terminal paste-board piping
    osc-copy() {
        local data
        data=$(cat)
        local len=''${#data}
        printf "\033]52;c;%s\a" "$(printf "%s" "$data" | base64 | tr -d '\n')"
    }
    export -f osc-copy
  '';

  # Declarative User Systemd Services
  systemd.user.services = {
    backup-piMitters = {
      Unit = {
        Description = "Daily Backup of piMitters Services and Sync to Google Drive";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${backup-piMitters-pkg}/bin/backup-piMitters";
      };
    };

    backup-sofia-q2h = {
      Unit = {
        Description = "Sofia Database 2-Hour Backup and Cloud Sync";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${backup-sofia-q2h-pkg}/bin/backup-sofia-q2h";
      };
    };


    geminios = {
      Unit = {
        Description = "Qwerty (geminiOS) Discord Bot";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "/home/kyle/geminiOS";
        ExecStart = "${pkgs.nodejs_24}/bin/node --experimental-strip-types src/index.ts";
        Restart = "on-failure";
        RestartSec = "10s";
        Environment = [ "NODE_ENV=production" "PATH=/run/current-system/sw/bin:/usr/bin" ];
        EnvironmentFile = "/home/kyle/geminiOS/.env";

        # Sandbox Rails
        ProtectHome = "tmpfs";
        BindPaths = [
          "/home/kyle/geminiOS"
          "/home/kyle/.gemini/state"
          "/home/kyle/.gemini/tmp/kyle"
          "/home/kyle/Documents/obsidian/dev/geminiOS/QwertyMemory"
        ];
        BindReadOnlyPaths = [
          "/home/kyle/Documents/obsidian"
          "/home/kyle/dev/agentic-memory-compiler"
          "/home/kyle/scripts"
          "/home/kyle/NixOS"
          "/home/kyle/.config/gmail-mcp"
          "/home/kyle/.config/google-calendar-mcp"
          "/home/kyle/.config/google-drive-mcp"
        ];
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        LimitNOFILE = 4096;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };


    milton = {
      Unit = {
        Description = "Milton Discord Bot and Paralegal";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "/home/kyle/milton";
        ExecStart = "${pkgs.nodejs_24}/bin/node --experimental-strip-types src/index.ts";
        Restart = "on-failure";
        RestartSec = "10s";
        Environment = [ "NODE_ENV=production" "PATH=/run/current-system/sw/bin:/usr/bin" ];
        EnvironmentFile = "/home/kyle/milton/.env";

        # Sandbox Rails
        ProtectHome = "tmpfs";
        BindPaths = [ "/home/kyle/milton" ];
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        LimitNOFILE = 4096;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  # Declarative User Systemd Timers
  systemd.user.timers = {
    backup-piMitters = {
      Unit = {
        Description = "Daily Backup of piMitters Services Timer";
      };
      Timer = {
        OnCalendar = "*-*-* 02:00:00";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };

    backup-sofia-q2h = {
      Unit = {
        Description = "Sofia Database 2-Hour Backup and Cloud Sync Timer";
      };
      Timer = {
        OnCalendar = "*-*-* 00/2:00:00";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };


  };

  # SSH Configuration (Pi5 settings)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "pi5 piMitters pimitters" = {
        HostName = "100.73.97.16";
        User = "kyle";
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = { TERM = "xterm-256color"; };
      };
      "nixMitters nixmitters" = {
        HostName = "100.113.20.33";
        User = "kyle";
        IdentityFile = "~/.ssh/id_ed25519";
        SetEnv = { TERM = "xterm-256color"; };
      };
    };
  };
}
