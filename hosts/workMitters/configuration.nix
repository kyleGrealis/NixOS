{ config, pkgs, ... }:

{
  # Hostname configuration
  networking.hostName = "wslNixMitters";

  # Time Zone and Locale
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # Network Mount: piCloud SMB share on Pi5
  fileSystems."/home/kyle/piCloud" = {
    device = "//100.73.97.16/piCloud";
    fsType = "cifs";
    options = [
      "credentials=/home/kyle/.smbcredentials"
      "uid=1000"
      "gid=100"
      "x-systemd.automount"
      "noauto"
      "_netdev"
      "x-systemd.idle-timeout=60"
    ];
  };

  # Define user account details
  users.groups.kyle = {};
  users.users.kyle = {
    isNormalUser = true;
    group = "kyle";
    description = "Kyle";
    extraGroups = [ "wheel" "docker" ];
  };

  # Link Documents to the Windows user's Documents folder
  system.activationScripts.linkDocuments = {
    text = ''
      mkdir -p /home/kyle
      if [ ! -L /home/kyle/Documents ]; then
        rm -rf /home/kyle/Documents
        ln -sfn /mnt/c/Users/kxg679/Documents /home/kyle/Documents
        chown -h kyle:users /home/kyle/Documents
      fi
    '';
    deps = [];
  };

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

  # Declarative Syncthing Configuration
  # We use non-override/non-declarative settings for devices and folders here
  # to prevent systemd-init from colliding with the Windows host on port 8384.
  services.syncthing = {
    enable = true;
    user = "kyle";
    dataDir = "/home/kyle";
    configDir = "/home/kyle/.local/state/syncthing";
    guiAddress = "127.0.0.1:45517";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
  };

  # Enable Tailscale
  services.tailscale.enable = true;

  # System-wide Packages
  environment.systemPackages = with pkgs; [
    git
    micro
    curl
    wget
    cifs-utils
  ];

  # Allow Unfree Packages
  nixpkgs.config.allowUnfree = true;

  # NixOS State Version
  system.stateVersion = "26.05";
}
