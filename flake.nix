{
  description = "My system configuration";

  inputs = {

    ayugram-desktop.url = "github:/ayugram-port/ayugram-desktop/release?submodules=1";
    ags.url = "github:Aylur/ags";
    
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    sops-nix.url = "github:Mic92/sops-nix";
    stylix.url = "github:danth/stylix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... }@inputs:

    let
      system = "x86_64-linux";
    in {

    nixosConfigurations.usconfig = nixpkgs.lib.nixosSystem {
      specialArgs = {
        pkgs-stable = import nixpkgs-stable {
          inherit system;
          config.allowUnfree = true;
        };
        inherit inputs system;
      };
      modules = [
       ./nixos/hosts/usconfig/configuration.nix
      ];
    };

    homeConfigurations.kirill = home-manager.lib.homeManagerConfiguration {
      extraSpecialArgs = {
          inherit inputs;
          };
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [
        ./home-manager/home.nix
        inputs.sops-nix.homeManagerModules.sops
        inputs.stylix.homeManagerModules.stylix
      ];
    };
  };
}
