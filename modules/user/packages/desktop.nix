{ pkgs, inputs, pkgs-stable, ... }: {
  home.packages = with pkgs; [
    ayugram-desktop
    obs-studio
    mpv
    obsidian
    pkgs-stable.qbittorrent
    libreoffice
    pear-desktop
    element-desktop
    gcr_3
  ];
}
