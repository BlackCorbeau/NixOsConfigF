{ lib, ... }: {
  environment.variables = {
    EDITOR = "hx";
    RANGER_LOAD_DEFAULT_RC = "FALSE";
    GTK_USE_PORTAL = "1";
    QT_QPA_PLATFORMTHEME = lib.mkForce "xdgdesktopportal";
    TDESKTOP_USE_GTK_FILE_DIALOG = "1";
  };
}
