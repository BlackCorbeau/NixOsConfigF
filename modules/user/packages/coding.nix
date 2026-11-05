
{ pkgs, ... }:

let
  #free-coding-models = import ./free-coding-models.nix {
  #  inherit pkgs;
  #};

  opencode-fixed = pkgs.opencode.overrideAttrs (old: {
    node_modules = old.node_modules.overrideAttrs (_: {
      outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
    });
  });
in
{
  home.packages = with pkgs; [
    android-studio
    lazygit
    git
    tree
    opencode-fixed
    #free-coding-models
    postgresql
    dbgate
  ];
}
