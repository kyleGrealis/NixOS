{ config, pkgs, ... }:

{
  imports = [
    ./home.nix
  ];

  home.stateVersion = "26.05";

  # wslNixMitters-specific user packages (WSL Environment)
  home.packages = with pkgs; [
    # Workstation Dev Tools
    antigravity      # Google Antigravity IDE package from Nixpkgs
    pandoc           # Document converter
    pre-commit       # Git hook manager
    quarto           # Publishing CLI
    uv               # Fast Python packaging (needed for memory compilers)
    python3          # Python interpreter
    
    # Migrated from Arch WSL Audit
    azure-cli        # Azure CLI
    bind             # DNS utilities (dig, host, etc.)
    dos2unix         # Line ending converter
    qpdf             # PDF transform tool
    discord          # Discord chat client
    btop             # System resource monitor

    # WSL Specific tools
    wl-clipboard     # Clipboard helper
  ];

  # Session path updates
  home.sessionPath = [
    "$HOME/.npm-global/bin"
  ];

  # Migrated environment variables
  home.sessionVariables = {
    DONT_PROMPT_WSL_INSTALL = "true";
    GDK_SCALE = "2";
    GDK_DPI_SCALE = "0.5";
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    CLAUDE_CODE_USE_FOUNDRY = "1";
    ANTHROPIC_FOUNDRY_RESOURCE = "uhealth-claude-code";
    ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-4-5";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-4-5";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-6";
    NVM_DIR = "$HOME/.nvm";
  };

  programs.bash.shellAliases = {
    # WSL-specific copy shortcut
    copy = "tee >(wl-copy)";
    nix-switch = "sudo nixos-rebuild switch --flake ~/NixOS#wslNixMitters";

    # Migrated aliases
    discord = "(discord &>/dev/null &)";
  };
}

