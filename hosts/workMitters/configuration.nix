{ config, pkgs, ... }:

{
  # Time Zone and Locale
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable nix-ld to run unpatched dynamic binaries (like agy, etc.)
  programs.nix-ld.enable = true;

  # Nix Settings (Enable Flakes and Optimize Store)
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    max-jobs = 4;
    cores = 2;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # System-wide Packages
  environment.systemPackages = with pkgs; [
    git
    micro
    curl
    wget
  ];

  # Allow Unfree Packages
  nixpkgs.config.allowUnfree = true;

  # NixOS State Version
  system.stateVersion = "26.05";
}
