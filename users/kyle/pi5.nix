{ config, pkgs, ... }:

let
  backup-pi5-pkg = pkgs.writeShellApplication {
    name = "backup-pi5";
    runtimeInputs = [
      pkgs.rsync
      pkgs.sqlite
      pkgs.rclone
      pkgs.docker
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.findutils
    ];
    text = builtins.readFile ../../scripts/backup-pi5.sh;
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

  compile-memory-pkg = pkgs.writeShellApplication {
    name = "compile-memory";
    runtimeInputs = [ pkgs.uv pkgs.python3 ];
    text = builtins.readFile ../../scripts/compile-memory.sh;
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
    
    # Declarative user utilities
    backup-pi5-pkg
    backup-sofia-q2h-pkg
    compile-memory-pkg
    get-carried-over-tasks-pkg
  ];

  programs.bash.shellAliases = {
    # Headless/server-specific aliases
    copy = "tee >(osc-copy)";
    nix-switch = "sudo nixos-rebuild switch --flake ~/NixOS#pi5";
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
    backup-pi5 = {
      Unit = {
        Description = "Daily Backup of pi5 Services and Sync to Google Drive";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${backup-pi5-pkg}/bin/backup-pi5";
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

    compile-memory = {
      Unit = {
        Description = "Compile daily memory logs into knowledge base";
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory = "/home/kyle/dev/agentic-memory-compiler";
        ExecStart = "${compile-memory-pkg}/bin/compile-memory";
        Environment = [
          "PATH=${pkgs.uv}/bin:${pkgs.python3}/bin:/run/current-system/sw/bin:/usr/bin"
          "COMPILE_USE_ANTHROPIC=true"
        ];
      };
    };

    flush-agy = {
      Unit = {
        Description = "Flush pending Agy/Gemini sessions into daily logs";
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory = "/home/kyle/dev/agentic-memory-compiler";
        ExecStart = "${pkgs.uv}/bin/uv run python scripts/flush_gemini.py";
        Environment = [
          "PATH=${pkgs.uv}/bin:${pkgs.python3}/bin:/run/current-system/sw/bin:/usr/bin"
        ];
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
        ExecStart = "${pkgs.nodejs_22}/bin/node --experimental-strip-types src/index.ts";
        Restart = "on-failure";
        RestartSec = "10s";
        Environment = [ "NODE_ENV=production" ];
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
          "/home/kyle/.config/gmail-mcp"
          "/home/kyle/.config/google-calendar-mcp"
          "/home/kyle/.config/google-drive-mcp"
        ];
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        LimitNOFILE = 4096;
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
        ExecStart = "${pkgs.nodejs_22}/bin/node --experimental-strip-types src/index.ts";
        Restart = "on-failure";
        RestartSec = "10s";
        Environment = [ "NODE_ENV=production" ];
        EnvironmentFile = "/home/kyle/milton/.env";

        # Sandbox Rails
        ProtectHome = "tmpfs";
        BindPaths = [ "/home/kyle/milton" ];
        ProtectSystem = "strict";
        PrivateTmp = true;
        NoNewPrivileges = true;
        LimitNOFILE = 4096;
      };
    };
  };

  # Declarative User Systemd Timers
  systemd.user.timers = {
    backup-pi5 = {
      Unit = {
        Description = "Daily Backup of pi5 Services Timer";
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

    compile-memory = {
      Unit = {
        Description = "Run memory compiler at 3am daily";
      };
      Timer = {
        OnCalendar = "*-*-* 03:00:00";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };

    flush-agy = {
      Unit = {
        Description = "Flush Agy/Gemini sessions every 30 minutes";
      };
      Timer = {
        OnCalendar = "*:00,30";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
