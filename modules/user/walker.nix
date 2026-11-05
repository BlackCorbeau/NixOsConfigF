{ config, lib, ... }:
let
  hyprLua = import ./hyprland/lua.nix { inherit lib; };
in {
  services = {
    walker = {
      enable = true;
      systemd.enable = true;
    };

    elephant.enable = true;
  };

  wayland.windowManager.hyprland.settings.bind = [
    (hyprLua.bind "SUPER + D"
      (if config.home.username == "kirill"
      then hyprLua.execLauncher "qs ipc call launcher toggle"
      else hyprLua.exec "walker"))
  ];

}
