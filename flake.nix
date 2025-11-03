{
  description = "My system configuration";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.garnix.io"
      "https://hyprland.cachix.org"
      "https://ezkea.cachix.org"
      "https://risdeveau.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "ezkea.cachix.org-1:ioBmUbJTZIKsHmWWXPe1FSFbeVe+afhfgqgTSNd34eI="
      "risdeveau.cachix.org-1:TsoFSVeLl7iKtUYGX7qsvKPjf2vbNLfLC5v3SAdU8r0="
    ];
  };
  
  inputs = {

    ayugram-desktop.url = "github:/ayugram-port/ayugram-desktop/release?submodules=1";
    ags.url = "github:Aylur/ags/3ed9737bdbc8fc7a7c7ceef2165c9109f336bff6";
    
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    sops-nix.url = "github:Mic92/sops-nix";
    stylix.url = "github:danth/stylix";

    compose2nix = {
      url = "github:aksiksi/compose2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... }@inputs:

    let
      system = "x86_64-linux";
    in {

    nixosConfigurations = {
      WhiteRaven = nixpkgs.lib.nixosSystem {
        specialArgs = {
          pkgs-stable = import nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
          };
          pkgs-unstable = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          inherit inputs system;
        };
        modules = [
         ./nixos/hosts/WhiteRaven/configuration.nix
        ];
      };
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
