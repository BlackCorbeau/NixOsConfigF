{ pkgs, lib, config, swww_flags, inputs, host ? null }:
let
  hyprLua = import ./hyprland/lua.nix { inherit lib; };
  direction = { left = "l"; right = "r"; up = "u"; down = "d"; };
  wallpaper_changer = pkgs.writers.writePython3Bin "wallpaper_changer" {
    libraries = [ pkgs.python3Packages.requests ];
    flakeIgnore = [ "E501" "E111" "E701" "E241" "E731" ];
  } /*py*/ ''
    from random import choice
    from os import system, listdir
    folder = "${config.home.homeDirectory}/wallpapers"
    filename = choice(listdir(folder))
    system(f"${lib.getExe pkgs.awww} img {folder}/{filename} ${swww_flags}")
  '';
  workspaceBinds = lib.concatMap (workspace:
    let key = if workspace == 10 then "0" else toString workspace; workspaceValue = toString workspace;
    in [
      (hyprLua.bind "SUPER + ${key}" "hl.dsp.focus({ workspace = ${workspaceValue} })")
      (hyprLua.bind "SUPER + SHIFT + ${key}" "hl.dsp.window.move({ workspace = ${workspaceValue}, follow = false })")
    ]) (lib.range 1 10);
in {
  imports = lib.optional (host != null && builtins.pathExists ../../host/${host.name}/modules/hyprland.nix) ../../host/${host.name}/modules/hyprland.nix;

  home.packages = with pkgs; [
    wallpaper_changer
    ghostty
    pamixer
    wofi
    clipse
    wl-clipboard
    wl-clip-persist
    xclip
  ];
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    plugins = with inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}; [ ];
    settings = {
      config = {
        ecosystem = { no_donation_nag = true; no_update_news = true; };
        cursor.no_hardware_cursors = 1;
        debug = { disable_logs = false; enable_stdout_logs = true; };
        general."col.inactive_border" = lib.mkDefault "rgba(00000000)";
        decoration = { inactive_opacity = lib.mkDefault 0.95; border_part_of_window = false; };
        misc.focus_on_activate = true;
        input = {
          kb_layout = "us,ru"; kb_options = "grp:caps_toggle"; numlock_by_default = true;
          follow_mouse = 1; touchpad.natural_scroll = false; sensitivity = 0;
        };
        gestures = { workspace_swipe_invert = true; workspace_swipe_distance = 200; workspace_swipe_forever = true; };
      };
      env = [
        { _args = [ "XDG_SESSION_TYPE" "wayland" ]; }
        { _args = [ "QT_QPA_PLATFORM" "wayland" ]; }
        { _args = [ "QT_QPA_PLATFORMTHEME" "xdgdesktopportal" ]; }
        { _args = [ "GTK_USE_PORTAL" "1" ]; }
        { _args = [ "TDESKTOP_USE_GTK_FILE_DIALOG" "1" ]; }
        { _args = [ "NIXOS_OZONE_WL" "1" ]; }
        { _args = [ "ELECTRON_OZONE_PLATFORM_HINT" "auto" ]; }
        { _args = [ "XDG_CURRENT_DESKTOP" "Hyprland" ]; }
        { _args = [ "XDG_SESSION_DESKTOP" "Hyprland" ]; }
        { _args = [ "XCURSOR_SIZE" (toString config.stylix.cursor.size) ]; }
        { _args = [ "XCURSOR_THEME" config.stylix.cursor.name ]; }
        { _args = [ "XDG_SCREENSHOTS_DIR" "~/screens" ]; }
      ];
      gesture = [ { fingers = 3; direction = "horizontal"; action = "workspace"; } ];
      workspace_rule = [ { workspace = "w[t1]"; gaps_out = 0; } ];
      window_rule = [
        { match.class = "imv"; float = true; }
        { match.class = "feh"; float = true; }
        { match.class = "mpv"; float = true; }
        { match.title = "Список друзей"; float = true; }
        { match.title = "wifitui"; float = true; }
        { match.title = "pulsemixer"; float = true; }
        { match.title = "clipse"; float = true; }
        { match.title = "clipse"; size = [ 622 652 ]; }
        { match.focus = true; rounding = 0; }
        { match = { float = false; workspace = "w[t1]"; }; border_size = 0; }
      ];
      on = [ (hyprLua.onStart [
        "systemctl --user start plasma-polkit-agent"
        "${lib.getExe' pkgs.dbus "dbus-update-activation-environment"} --systemd --all"
        "systemctl --user import-environment XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE WAYLAND_DISPLAY DISPLAY GTK_USE_PORTAL QT_QPA_PLATFORMTHEME TDESKTOP_USE_GTK_FILE_DIALOG NIXOS_OZONE_WL ELECTRON_OZONE_PLATFORM_HINT"
        "${lib.getExe' pkgs.awww "awww-daemon"}"
        "wl-clip-persist --clipboard both"
        "clipse -listen"
        "${lib.getExe' pkgs.udiskie "udiskie"}"
        "${lib.getExe wallpaper_changer}"
      ]) ];
      bind = [
        (hyprLua.bind "SUPER + V" (hyprLua.exec "ghostty --title=clipse -e clipse"))
        (hyprLua.bind "SUPER + RETURN" (hyprLua.exec "ghostty"))
        (hyprLua.bind "SUPER + Q" "hl.dsp.window.close()")
        (hyprLua.bind "SUPER + M" "hl.dsp.exit()")
        (hyprLua.bind "SUPER + E" (hyprLua.exec "ghostty -e sh -c yazi"))
        (hyprLua.bind "SUPER + F" "hl.dsp.window.float({ action = \"toggle\" })")
        (hyprLua.bind "SUPER + J" "hl.dsp.layout(\"togglesplit\")")
        (hyprLua.bind "SUPER + W" (hyprLua.exec "${lib.getExe wallpaper_changer}"))
        (hyprLua.bind "SUPER + LEFT" "hl.dsp.focus({ direction = \"${direction.left}\" })")
        (hyprLua.bind "SUPER + RIGHT" "hl.dsp.focus({ direction = \"${direction.right}\" })")
        (hyprLua.bind "SUPER + UP" "hl.dsp.focus({ direction = \"${direction.up}\" })")
        (hyprLua.bind "SUPER + DOWN" "hl.dsp.focus({ direction = \"${direction.down}\" })")
        (hyprLua.bind "SUPER + SHIFT + LEFT" "hl.dsp.window.swap({ direction = \"${direction.left}\" })")
        (hyprLua.bind "SUPER + SHIFT + RIGHT" "hl.dsp.window.swap({ direction = \"${direction.right}\" })")
        (hyprLua.bind "SUPER + SHIFT + UP" "hl.dsp.window.swap({ direction = \"${direction.up}\" })")
        (hyprLua.bind "SUPER + SHIFT + DOWN" "hl.dsp.window.swap({ direction = \"${direction.down}\" })")
        (hyprLua.bind "SUPER + CTRL + LEFT" "hl.dsp.window.resize({ x = -60, y = 0, relative = true })")
        (hyprLua.bind "SUPER + CTRL + RIGHT" "hl.dsp.window.resize({ x = 60, y = 0, relative = true })")
        (hyprLua.bind "SUPER + CTRL + UP" "hl.dsp.window.resize({ x = 0, y = -60, relative = true })")
        (hyprLua.bind "SUPER + CTRL + DOWN" "hl.dsp.window.resize({ x = 0, y = 60, relative = true })")
      ] ++ workspaceBinds ++ [
        (hyprLua.bind "SUPER + SHIFT + F" "hl.dsp.window.fullscreen({ action = \"toggle\", mode = \"fullscreen\" })")
        (hyprLua.bind "SUPER + mouse_down" "hl.dsp.focus({ workspace = \"e+1\" })")
        (hyprLua.bind "SUPER + mouse_up" "hl.dsp.focus({ workspace = \"e-1\" })")
        (hyprLua.bind "SUPER + F3" (hyprLua.exec "${lib.getExe pkgs.brightnessctl} -d *::kbd_backlight set +33%"))
        (hyprLua.bind "SUPER + F2" (hyprLua.exec "${lib.getExe pkgs.brightnessctl} -d *::kbd_backlight set 33%-"))
        (hyprLua.bind "XF86AudioMute" (hyprLua.exec "pamixer -t"))
        (hyprLua.bind "XF86AudioMicMute" (hyprLua.exec "pamixer --default-source -m"))
        (hyprLua.bind "XF86AudioPlay" (hyprLua.exec "${lib.getExe pkgs.playerctl} play-pause"))
        (hyprLua.bind "XF86AudioPrev" (hyprLua.exec "${lib.getExe pkgs.playerctl} position 5-"))
        (hyprLua.bind "XF86AudioNext" (hyprLua.exec "${lib.getExe pkgs.playerctl} position 5+"))
        (hyprLua.bind "XF86Explorer" (hyprLua.exec "ghostty -e sh -c yazi"))
        (hyprLua.bind "XF86Mail" (hyprLua.exec "thunderbird"))
        (hyprLua.bind "XF86WWW" (hyprLua.exec "google-chrome-stable"))
        (hyprLua.bind "XF86MonBrightnessDown" (hyprLua.exec "${lib.getExe pkgs.brightnessctl} set 5%-"))
        (hyprLua.bind "XF86MonBrightnessUp" (hyprLua.exec "${lib.getExe pkgs.brightnessctl} set +5%"))
        (hyprLua.bindWithFlags "XF86AudioRaiseVolume" (hyprLua.exec "pamixer -i 5") { repeating = true; })
        (hyprLua.bindWithFlags "XF86AudioLowerVolume" (hyprLua.exec "pamixer -d 5") { repeating = true; })
        (hyprLua.bindWithFlags "XF86AudioPrev" (hyprLua.exec "${lib.getExe pkgs.playerctl} previous") { long_press = true; })
        (hyprLua.bindWithFlags "XF86AudioNext" (hyprLua.exec "${lib.getExe pkgs.playerctl} next") { long_press = true; })
        (hyprLua.bindWithFlags "SUPER + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
        (hyprLua.bindWithFlags "SUPER + mouse:273" "hl.dsp.window.resize()" { mouse = true; })
      ];
    };
  };
}
