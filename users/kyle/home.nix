{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage.
  home.username = "kyle";
  home.homeDirectory = "/home/kyle";
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "26.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # User-specific packages
  home.packages = with pkgs; [
    # Utilities
    eza
    fastfetch
    trash-cli
    ripgrep
    fzf
    micro
    delta
    tealdeer
    tree
    wl-clipboard     # Clipboard helper for Wayland
    just             # Command runner
    git-lfs          # Large file support for Git
    gh               # GitHub CLI
    lsof             # List open files
    tcpdump          # Network packet analyzer
    nmap             # Network scanner
    btop             # System monitor
    ghostty          # GPU-accelerated terminal emulator

    # Dev Environments & Tools
    positron-bin
    antigravity      # Google Antigravity IDE package from Nixpkgs
    quarto           # Publishing CLI
    pandoc           # Document converter
    pre-commit       # Git hook manager

    # User Applications
    brave            # Brave browser
    google-chrome    # Google Chrome browser
    discord          # Discord chat client
    slack            # Slack chat client
    spotify          # Spotify music player
    obsidian         # Markdown knowledge base
    emote            # Emoji picker
    zoom-us          # Zoom meetings client
    zotero           # Reference manager
    proton-pass      # Proton Pass desktop client
    gimp             # GNU Image Manipulation Program
    libreoffice      # Office productivity suite
  ];

  # Bash configuration
  programs.bash = {
    enable = true;
    enableCompletion = true;
    
    # Environment Variables
    sessionVariables = {
      EDITOR = "micro";
      HISTCONTROL = "ignoreboth:erasedups";
      HISTSIZE = "10000";
      HISTFILESIZE = "10000";
    };

    # Shell Aliases
    shellAliases = {
      # Safe file deletion alternatives
      tp = "trash-put";
      tl = "trash-list";
      te = "trash-empty";
      rm = "rm -I --preserve-root";

      # Modern ls replacement (eza)
      ls = "eza -lh --group-directories-first --icons=auto";
      lsa = "ls -a";
      lt = "eza --tree --level=2 --long --icons --git";
      lta = "lt -a";

      # Git shortcodes
      gst = "git status";
      gs = "git switch";
      gd = "git diff -U0";
      gpush = "git push";
      gpull = "git pull";

      # Utilities
      now = "date +'%F %T'";
      weather = "curl wttr.in/Dallas?0";
      rsync = "rsync -azH --info=progress2";
      copy = "tee >(wl-copy)";
      ff = "clear && fastfetch";
      rs = "Rscript -e";

      # Personal Machine
      nix-switch = "sudo nixos-rebuild switch --flake ~/nix-config#nixMitters";
      watch-gpu = "watch -n 0.5 nvidia-smi";
      kdererun = "pkill -f kdeconnectd; (/usr/bin/kdeconnectd > /dev/null 2>&1 & disown)";
    };

    # Custom functions and hooks to append to .bashrc
    initExtra = ''
      # Ensure local bin is in PATH (workaround for Wayland/GNOME session vars)
      export PATH="$HOME/.local/bin:$PATH"

      # Git branch parsing for prompt
      parse_git_branch() {
          git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
      }

      # Custom prompt
      PS1='\n\[\033[1;34m\]\W\[\033[0;35m\]$(parse_git_branch) \[\033[0m\]\n\[\033[0;32m\]\h\[\033[0m\] >> '

      # Smart directory jump
      zd() {
          z "$@"
      }
      alias cd="zd"

      cdl() {
          zd "$@"
          eza -lha --group-directories-first --icons=auto
      }

      open() {
          xdg-open "$@" >/dev/null 2>&1 &
      }

      gam() {
          for file in "''${@:1:''$#-1}"; do
              git add "$file"
          done
          git commit -m "''${!#}"
      }

      restart() {
          source "$HOME/.bashrc"
      }

      # Silenced Positron launcher (suppresses warnings and job/process ID printing)
      positron() {
          ( /usr/share/positron/positron "$@" >/dev/null 2>&1 & )
      }
    '';
  };

  # Git Configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Kyle Grealis";
        email = "kyle@kylegrealis.com";
      };
      credential.helper = "cache";
      core = {
        excludesFile = "~/.gitignore";
        autocrlf = false;
        editor = "micro";
        eol = "lf";
        pager = "delta";
      };
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Coldark-Dark";
      };
      merge.conflictstyle = "zdiff3";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoStash = true;
      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };
    };
  };

  # Direnv Configuration
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Zoxide Configuration
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # Declarative Out-of-Store Symlinks for agent settings sync via Obsidian
  home.file = {
    ".gemini/antigravity-cli/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/obsidian/dev/agent-guidelines/settings/settings.json";
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/obsidian/dev/agent-guidelines/settings/claude-settings.json";
  };

  # Declarative GNOME Keybindings and Settings
  dconf.settings = {
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
      minimize = [ "<Super>down" ];
      maximize = [ "<Super>up" ];
      unmaximize = [ "<Super>down" ];
      
      # Direct workspace jumps (Workspaces 1-9)
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

      # Sliding workspace navigation (Horizontal movement)
      switch-to-workspace-left = [ "<Super><Alt>Left" ];
      switch-to-workspace-right = [ "<Super><Alt>Right" ];
      move-to-workspace-left = [ "<Super><Shift><Alt>Left" ];
      move-to-workspace-right = [ "<Super><Shift><Alt>Right" ];

      # Disable default Super+Space input layout switcher to prevent conflicts
      switch-input-source = [];
    };

    # Map Super+Space to launch the GNOME Application Grid (App Picker)
    "org/gnome/shell/keybindings" = {
      toggle-application-view = [ "<Super>space" ];
    };

    "org/gnome/desktop/wm/preferences" = {
      # Drag windows by clicking anywhere on the window while holding the Super key
      mouse-button-modifier = "<Super>";
    };

    # Declarative Custom App Launchers (from legacy COSMIC configuration)
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
}
