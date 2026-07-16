{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage.
  home.username = "kyle";
  home.homeDirectory = "/home/kyle";
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # User-specific packages
  home.packages = with pkgs; [
    # Utilities
    eza              # Modern ls replacement
    fastfetch        # System info tool
    fzf              # Fuzzy finder
    gh               # GitHub CLI
    git-lfs          # Large file support for Git
    just             # Command runner
    lsof             # List open files
    micro            # Terminal text editor
    nmap             # Network scanner
    ripgrep          # Fast text search
    tcpdump          # Network packet analyzer
    tealdeer         # Fast tldr client
    trash-cli        # Safe command-line trash
    tree             # Directory tree visualizer
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

    shellAliases = {
      # Safe file deletion alternatives
      tp = "trash-put";
      tl = "trash-list";
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
      ff = "clear && fastfetch";
      rs = "Rscript -e";
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

    '';
  };

  # Git Configuration
  programs.git = {
    enable = true;
    ignores = [ "**/.claude/settings.local.json" ];
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

  # XDG MIME Applications and User Directories
  xdg = {
    enable = true;

    mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = [ "onlyoffice-desktopeditors.desktop" ];
        "application/x-terminal-emulator" = [ "com.mitchellh.ghostty.desktop" ];
        "text/html" = [ "google-chrome.desktop" ];
        "text/markdown" = [ "positron.desktop" ];
        "text/plain" = [ "positron.desktop" ];
        "text/x-r" = [ "positron.desktop" ];
        "text/x-quarto" = [ "positron.desktop" ];
        "text/x-typescript" = [ "positron.desktop" ];
        "text/javascript" = [ "positron.desktop" ];
        "x-scheme-handler/about" = [ "google-chrome.desktop" ];
        "x-scheme-handler/http" = [ "google-chrome.desktop" ];
        "x-scheme-handler/https" = [ "google-chrome.desktop" ];
        "x-scheme-handler/mailto" = [ "gmail.desktop" ];
        "x-scheme-handler/slack" = [ "slack.desktop" ];
        "x-scheme-handler/terminal" = [ "com.mitchellh.ghostty.desktop" ];
      };
    };

    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/";
      pictures = "${config.home.homeDirectory}/Pictures";
      publicShare = "${config.home.homeDirectory}/";
      templates = "${config.home.homeDirectory}/";
      videos = "${config.home.homeDirectory}/Videos";
      extraConfig = {
        XDG_PROJECTS_DIR = "${config.home.homeDirectory}/Projects";
      };
    };
  };

  # Declarative Out-of-Store Symlinks for agent settings sync via Obsidian
  home.file = {
    ".gemini/antigravity-cli/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/obsidian/dev/agent-guidelines/settings/settings.json";
      force = true;
    };
    ".claude/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Documents/obsidian/dev/agent-guidelines/settings/claude-settings.json";
      force = true;
    ".config/Positron/User/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/positron/settings.json";
      force = true;
    };
    ".config/Positron/User/keybindings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/positron/keybindings.json";
      force = true;
    };
    ".config/ghostty/config" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/ghostty/config";
      force = true;
    };
    ".config/micro/settings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/micro/settings.json";
      force = true;
    };
    ".config/micro/bindings.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/micro/bindings.json";
      force = true;
    };
    ".config/btop/btop.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/btop/btop.conf";
      force = true;
    };
    ".config/fastfetch/config.jsonc" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/NixOS/users/kyle/configs/fastfetch/config.jsonc";
      force = true;
    };
  };
}
