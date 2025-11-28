{ pkgs, ... }: {
  home.packages = with pkgs; [
    jetbrains.idea-community
    android-studio
    lazygit
    git
    tree
    zed-editor
    postgresql
    dbgate
  ];
}
