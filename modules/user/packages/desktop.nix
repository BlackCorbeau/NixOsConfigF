{ pkgs, inputs, pkgs-fixed, ... }: {
  home.packages = with pkgs; [
    pkgs-fixed.ayugram-desktop
    obs-studio
    mpv
    obsidian
    qbittorrent
    libreoffice
  ];
}
