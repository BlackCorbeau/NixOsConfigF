{ pkgs, ... }: {
  home.packages = with pkgs; [
    jetbrains.idea-oss
    android-studio
    lazygit
    git
    tree
    zed-editor
    postgresql
    dbgate
  ];
}
