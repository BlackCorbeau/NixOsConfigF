{ pkgs, ... }:

let
  free-coding-models = import ./free-coding-models.nix {
    inherit pkgs;
  };
in
{
  home.packages = with pkgs; [
    #jetbrains.idea-oss
    android-studio
    lazygit
    git
    tree
    opencode
    free-coding-models
    postgresql
    dbgate
  ];
}
