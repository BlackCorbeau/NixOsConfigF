{ pkgs, lib, config, ... }: {
  wayland.windowManager.hyprland =
  let
    colors = config.lib.stylix.colors;
    
    wallpaper_changer = pkgs.writers.writePython3Bin "wallpaper_changer" {
      flakeIgnore = [ "E501" "E111" "E701" "E241" "E731" ];
    } /*py*/ '' 
      from random import choice
      from os import system, listdir

      folder = "/home/kirill/wallpapers"
      filename = choice(listdir(folder))
      system(f"swww img {folder}/{filename} --transition-type center")
    '';
  in {
    enable = true;
    xwayland.enable = true;

    settings = {
      "$mainMod" = "SUPER";

      monitor = ",preferred,auto,1";

      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "WLR_NO_HARDWARE_CURSORS,1"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XCURSOR_SIZE,36"
        "QT_QPA_PLATFORM,wayland"
        "XDG_SCREENSHOTS_DIR,~/screens"
      ];

      debug = {
        disable_logs = false;
        enable_stdout_logs = true;
      };

      input = {
        kb_layout = "us,ru";
        kb_options = "grp:caps_toggle";

        follow_mouse = 1;

        touchpad = {
          natural_scroll = false;
        };

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
      };

      general = {
        gaps_in = 5;
        gaps_out = 20;
        border_size = 3;
        "col.active_border" = "rgba(${colors.base0C}ee) rgba(${colors.base0B}ee) 45deg";
        "col.inactive_border" = "rgba(${colors.base05}aa)";

        layout = "dwindle";
      };

      decoration = {
        rounding = 10;

        blur = {
          enabled = true;
          size = 16;
          passes = 2;
          new_optimizations = true;
        };

      };

      animations = {
        enabled = true;

        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        # bezier = "myBezier, 0.33, 0.82, 0.9, -0.08";

        animation = [
          "windows,     1, 7,  myBezier"
          "windowsOut,  1, 7,  default, popin 80%"
          "border,      1, 10, default"
          "borderangle, 1, 8,  default"
          "fade,        1, 7,  default"
          "workspaces,  1, 6,  default"
        ];
      };

      dwindle = {
        pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        smart_split = true;
      };

      master = {
        new_status = "master";
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_invert = true;
        workspace_swipe_distance = 200;
        workspace_swipe_forever = true;
      };

      misc = {
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        enable_swallow = true;
        render_ahead_of_time = false;
        disable_hyprland_logo = false;
      };

      windowrule = [
        "float, class:^(imv)$"
        "float, class:^(feh)$"
        "float, class:^(mpv)$"
        "float, class:^(nmtui)$"
        "float, title:^(Список друзей)"
      ];

      exec-once = [
          "systemctl --user start plasma-polkit-agent"
          "swww init"
          "python3 ${lib.getExe wallpaper_changer}"
          "${lib.getExe' pkgs.udiskie "udiskie"}"
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"
      ];

      bind = [
        "$mainMod, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

        "$mainMod, Return, exec, ghostty"
        "$mainMod, Q, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, ghostty -e sh -c yazi"
        "$mainMod, F, togglefloating,"
        "$mainMod, D, exec, wofi --show drun"
        "$mainMod, P, pseudo, # dwindle"
        "$mainMod, J, togglesplit, # dwindle"

        # Move focus with mainMod + arrow keys
        "$mainMod, left,  movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up,    movefocus, u"
        "$mainMod, down,  movefocus, d"

        # Moving windows
        "$mainMod SHIFT, left,  swapwindow, l"
        "$mainMod SHIFT, right, swapwindow, r"
        "$mainMod SHIFT, up,    swapwindow, u"
        "$mainMod SHIFT, down,  swapwindow, d"

        # Window resizing                     X  Y
        "$mainMod CTRL, left,  resizeactive, -60 0"
        "$mainMod CTRL, right, resizeactive,  60 0"
        "$mainMod CTRL, up,    resizeactive,  0 -60"
        "$mainMod CTRL, down,  resizeactive,  0  60"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, movetoworkspacesilent, 1"
        "$mainMod SHIFT, 2, movetoworkspacesilent, 2"
        "$mainMod SHIFT, 3, movetoworkspacesilent, 3"
        "$mainMod SHIFT, 4, movetoworkspacesilent, 4"
        "$mainMod SHIFT, 5, movetoworkspacesilent, 5"
        "$mainMod SHIFT, 6, movetoworkspacesilent, 6"
        "$mainMod SHIFT, 7, movetoworkspacesilent, 7"
        "$mainMod SHIFT, 8, movetoworkspacesilent, 8"
        "$mainMod SHIFT, 9, movetoworkspacesilent, 9"
        "$mainMod SHIFT, 0, movetoworkspacesilent, 10"

        "$mainMod SHIFT, F, fullscreen"
        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"

        # Keyboard backlight
        "$mainMod, F3, exec, brightnessctl -d *::kbd_backlight set +33%"
        "$mainMod, F2, exec, brightnessctl -d *::kbd_backlight set 33%-"

        # Volume and Media Control
        ", XF86AudioRaiseVolume, exec, pamixer -i 5 "
        ", XF86AudioLowerVolume, exec, pamixer -d 5 "
        ", XF86AudioMute, exec, pamixer -t"
        ", XF86AudioMicMute, exec, pamixer --default-source -m"
        
        # Brightness control
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%- "
        ", XF86MonBrightnessUp, exec, brightnessctl set +5% "

        # Configuration files
        ''$mainMod ALT, N, exec, ghostty -e sh -c "rb"''
        ''$mainMod ALT, C, exec, ghostty -e sh -c "conf"''
        ''$mainMod ALT, H, exec, ghostty -e sh -c "$EDITOR ~/nix/home-manager/modules/wms/hyprland.nix"''
        ''$mainMod ALT, W, exec, ghostty -e sh -c "$EDITOR ~/nix/home-manager/modules/wms/waybar.nix"''
        '', Print, exec, grim -g "$(slurp)" - | swappy -f -''

        # Waybar
        "$mainMod, B, exec, pkill -SIGUSR1 waybar"
        #"$mainMod, W, exec, pkill -SIGUSR2 waybar"

        "$mainMod, W, exec, python3 ${lib.getExe wallpaper_changer}"

        # Disable all effects
        "$mainMod Shift, G, exec, ~/.config/hypr/gamemode.sh "
        # Skreens
        ''$mainMod SHIFT, S, exec, alacritty -e sh -c "screenshot"''

        '', F11, exec, ghostty -e sh -c "hyprlock"''
        
      ];

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
    };
  };
}
