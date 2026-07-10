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

      # Personal Machine
      nix-switch = "sudo nixos-rebuild switch --flake ~/nix-config#nixMitters";
      watch-gpu = "watch -n 0.5 nvidia-smi";
      kdererun = "pkill -f kdeconnectd; (/usr/bin/kdeconnectd > /dev/null 2>&1 & disown)";
    };

    # Custom functions and hooks to append to .bashrc
    initExtra = ''
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
    userName = "Kyle Grealis";
    userEmail = "kyle@kylegrealis.com";
    
    extraConfig = {
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
}
