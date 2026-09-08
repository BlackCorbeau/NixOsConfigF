{ lib, ... }: {
  stylix.targets.qt.standardDialogs = "xdgdesktopportal";

  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = lib.mkForce "xdgdesktopportal";
    TDESKTOP_USE_GTK_FILE_DIALOG = "1";
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
  };
}
