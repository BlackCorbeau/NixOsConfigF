{ pkgs, ... }: {

  home.packages = with pkgs; [
    element-desktop
    gcr_3
  ];

  # Автозапуск Element в системном трее
  home.file.".config/autostart/element-desktop-tray.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Element Desktop (Tray)
    Comment=Start Element minimized to system tray
    Exec=${pkgs.element-desktop}/bin/element-desktop --hidden
    Terminal=false
    StartupNotify=false
    X-GNOME-Autostart-enabled=true
  '';
}
