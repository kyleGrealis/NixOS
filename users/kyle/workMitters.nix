{ config, pkgs, ... }:

{
  imports = [
    ./home.nix
  ];

  home.stateVersion = "26.05";

  # workMitters-specific user packages (WSL Environment)
  home.packages = with pkgs; [
    # Workstation Dev Tools
    antigravity      # Google Antigravity IDE package from Nixpkgs
    pandoc           # Document converter
    positron-bin     # Positron IDE binary
    pre-commit       # Git hook manager
    quarto           # Publishing CLI
    
    # WSL Specific tools
    wl-clipboard     # Clipboard helper
  ];

  programs.bash.shellAliases = {
    # WSL-specific copy shortcut
    copy = "tee >(wl-copy)";
    nix-switch = "sudo nixos-rebuild switch --flake ~/NixOS#workMitters";
  };
}
