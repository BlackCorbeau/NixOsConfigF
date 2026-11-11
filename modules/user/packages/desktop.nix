{ pkgs, inputs, pkgs-stable, ... }: {
  imports = [
    ./matrix.nix
  ];

  home.packages = with pkgs; [
    ayugram-desktop
    obs-studio
    mpv
    obsidian
    pkgs-stable.qbittorrent
    libreoffice
    pear-desktop
  ];
}
