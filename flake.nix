{
  description = "Kyle's NixOS System Config Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
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
          home-manager.users.kyle = import ./users/kyle/home.nix;
        }
      ];
    };
  };
}
