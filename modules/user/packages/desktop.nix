{ pkgs, inputs, pkgs-pinned, ... }: {
  home.packages = with pkgs; [
    pkgs-pinned.ayugram-desktop
    obs-studio
    mpv
    obsidian
    qbittorrent
    libreoffice
  ];
}
