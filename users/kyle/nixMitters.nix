{ config, pkgs, ... }:

let
  backup-nixMitters-pkg = pkgs.writeShellApplication {
    name = "backup-nixMitters";
    runtimeInputs = [
      pkgs.rsync
      pkgs.coreutils
    ];
    text = builtins.readFile ../../scripts/backup-nixMitters.sh;
  };
in
{
  imports = [
    ./home.nix
  ];

  home.stateVersion = "26.05";

  # nixMitters-specific user packages
  home.packages = with pkgs; [
    # Workstation Dev Tools
    antigravity      # Google Antigravity IDE package from Nixpkgs
    pandoc           # Document converter
    positron-bin     # Positron IDE binary
    pre-commit       # Git hook manager
    quarto           # Publishing CLI

    # User Applications (GUI)
    brave            # Brave browser
    discord          # Discord chat client
    emote            # Emoji picker
    ghostty          # Terminal
    gimp             # GNU Image Manipulation Program
    google-chrome    # Google Chrome browser
    libreoffice      # Office productivity suite
    obsidian         # Markdown knowledge base
    proton-pass      # Proton Pass desktop client
    slack            # Slack chat client
    spotify          # Spotify music player
    zoom-us          # Zoom meetings client
    zotero           # Reference manager
    
    # Graphic and workstation specifics
    delta            # Git diff tool (used for pager)
    wl-clipboard     # Clipboard helper for Wayland
    
    backup-nixMitters-pkg
  ];

  programs.bash.shellAliases = {
    # Workstation-specific aliases
    copy = "tee >(wl-copy)";
    nix-switch = "sudo nixos-rebuild switch --flake ~/NixOS#nixMitters";
    watch-gpu = "watch -n 0.5 nvidia-smi";
  };

  programs.bash.initExtra = ''
    # Silenced Positron launcher (suppresses warnings and job/process ID printing)
    positron() {
        ( command positron "$@" >/dev/null 2>&1 & )
    }
  '';

  # Declarative GNOME Keybindings and Settings
  dconf.settings = {
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
      minimize = [ "<Super>down" ];
      maximize = [ "<Super>up" ];
      unmaximize = [ "<Super>down" ];
      
      switch-to-workspace-1 = [ "<Super>1" ];
      switch-to-workspace-2 = [ "<Super>2" ];
      switch-to-workspace-3 = [ "<Super>3" ];
      switch-to-workspace-4 = [ "<Super>4" ];
      switch-to-workspace-5 = [ "<Super>5" ];
      switch-to-workspace-6 = [ "<Super>6" ];
      switch-to-workspace-7 = [ "<Super>7" ];
      switch-to-workspace-8 = [ "<Super>8" ];
      switch-to-workspace-9 = [ "<Super>9" ];

      move-to-workspace-1 = [ "<Super><Shift>1" ];
      move-to-workspace-2 = [ "<Super><Shift>2" ];
      move-to-workspace-3 = [ "<Super><Shift>3" ];
      move-to-workspace-4 = [ "<Super><Shift>4" ];
      move-to-workspace-5 = [ "<Super><Shift>5" ];
      move-to-workspace-6 = [ "<Super><Shift>6" ];
      move-to-workspace-7 = [ "<Super><Shift>7" ];
      move-to-workspace-8 = [ "<Super><Shift>8" ];
      move-to-workspace-9 = [ "<Super><Shift>9" ];

      switch-to-workspace-left = [ "<Super><Alt>Left" ];
      switch-to-workspace-right = [ "<Super><Alt>Right" ];
      move-to-workspace-left = [ "<Super><Shift><Alt>Left" ];
      move-to-workspace-right = [ "<Super><Shift><Alt>Right" ];

      switch-input-source = [];
    };

    "org/gnome/shell/keybindings" = {
      toggle-application-view = [ "<Super>space" ];
    };

    "org/gnome/desktop/wm/preferences" = {
      mouse-button-modifier = "<Super>";
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/"
      ];
      rotate-video-lock-static = [];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super>Return";
      command = "ghostty";
      name = "Launch Terminal (Ghostty)";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Super>b";
      command = "google-chrome";
      name = "Launch Chrome";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super><Shift>b";
      command = "google-chrome --incognito";
      name = "Launch Chrome (Incognito)";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      binding = "<Super>m";
      command = "spotify";
      name = "Launch Spotify";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
      binding = "<Super>t";
      command = "ghostty -e btop";
      name = "Launch System Monitor (btop)";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
      binding = "<Super>e";
      command = "google-chrome --app=https://mail.google.com";
      name = "Launch Gmail";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6" = {
      binding = "<Super>p";
      command = "positron";
      name = "Launch Positron";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7" = {
      binding = "<Super>o";
      command = "obsidian";
      name = "Launch Obsidian";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8" = {
      binding = "<Super>s";
      command = "slack";
      name = "Launch Slack";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9" = {
      binding = "<Super>c";
      command = "google-chrome --app=https://www.claude.ai";
      name = "Launch Claude AI";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10" = {
      binding = "<Super>slash";
      command = "google-chrome --app=https://messages.google.com";
      name = "Launch Google Messages";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11" = {
      binding = "<Super>d";
      command = "discord";
      name = "Launch Discord";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12" = {
      binding = "<Super>period";
      command = "emote";
      name = "Launch Emoji Picker (Emote)";
    };
  };

  # Autostart applications on GNOME login
  xdg.configFile."autostart/ghostty.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Ghostty
    Exec=ghostty --maximize
    Icon=com.mitchellh.ghostty
    Comment=GPU-accelerated terminal emulator
    Categories=System;TerminalEmulator;
    StartupNotify=true
    Terminal=false
  '';

  # Declarative User Systemd Services
  systemd.user.services = {
    backup-nixMitters = {
      Unit = {
        Description = "Daily Local Backup of nixMitters Configs to piCloud";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${backup-nixMitters-pkg}/bin/backup-nixMitters";
      };
    };
  };

  # Declarative User Systemd Timers
  systemd.user.timers = {
    backup-nixMitters = {
      Unit = {
        Description = "Daily Local Backup of nixMitters Configs Timer";
      };
      Timer = {
        OnCalendar = "*-*-* 01:00:00";
        Persistent = true;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };

  # GTK Theme and Icons
  gtk = {
    enable = true;
    iconTheme = {
      name = "MoreWaita";
      package = pkgs.morewaita-icon-theme;
    };
  };

  # Workstation-specific configurations
  home.file = {
    # Monitor layout configuration
    ".config/monitors.xml" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/monitors.xml";
      force = true;
    };
    # Zoom meetings client configuration (keeps client settings mutable)
    ".config/zoomus.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/zoom/zoomus.conf";
      force = true;
    };
  };
}
