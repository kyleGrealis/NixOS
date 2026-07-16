{
  description = "Kyle's NixOS System Config Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, home-manager-stable, nixos-raspberrypi, nixos-wsl, ... }@inputs: {
    nixosConfigurations.nixMitters = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        # Integrate Custom Overlays
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            (self: super: {
              google-sans = self.callPackage ./pkgs/google-sans.nix {};
            })
          ];
        })

        # System-level configurations
        ./hosts/nixMitters/configuration.nix
        
        # Integrate Home Manager as a system module
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.kyle = import ./users/kyle/nixMitters.nix;
        }
      ];
    };

    nixosConfigurations.workMitters = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        nixos-wsl.nixosModules.default
        {
          wsl.enable = true;
          wsl.defaultUser = "kyle";
        }
        ./hosts/workMitters/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.kyle = import ./users/kyle/workMitters.nix;
        }
      ];
    };

    nixosConfigurations.nixPi5 = nixos-raspberrypi.lib.nixosSystem {
      specialArgs = inputs;
      modules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        ./hosts/nixPi5/configuration.nix
        home-manager-stable.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.kyle = import ./users/kyle/nixPi5.nix;
        }
      ];
    };

    # Target for building the custom ready-to-flash SD card image
    nixosConfigurations.nixPi5-installer = nixos-raspberrypi.lib.nixosInstaller {
      specialArgs = inputs;
      modules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        ./hosts/nixPi5/configuration.nix
        home-manager-stable.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.kyle = import ./users/kyle/nixPi5.nix;
        }
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            (self: super: {
              # Bypass QEMU emulation crash during R package builds by using a dummy R env
              rEnv = pkgs.runCommand "r-env-dummy" {} "mkdir -p $out/bin $out/lib/R";
            })
          ];
        })
      ];
    };
  };
}
