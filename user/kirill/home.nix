{ pkgs, ... }: {
  imports = [
    ../../modules/user/packages/coding.nix
  ];
  programs.hyprlock.enable = true;
  home.packages = with pkgs; [
    vivaldi
  ];
}
