{ pkgs, lib, config, inputs, host, ... }:
let
  wallpaper_changer = pkgs.writers.writePython3Bin "wallpaper_changer" {
    libraries = [ pkgs.python3Packages.requests ];
    flakeIgnore = [ "E501" "E111" "E701" "E241" "E731" ];
  } /*py*/ ''
    from random import choice
    from os import system, listdir
    folder = "${config.home.homeDirectory}/wallpapers"
    filename = choice(listdir(folder))
    system(f"${lib.getExe pkgs.awww} img {folder}/{filename} --transition-type center")
  '';
in {
  imports = [(
    import ../../../modules/user/hyprland.nix {
      inherit lib;
      inherit pkgs;
      inherit config;
      inherit inputs;
      inherit host;
    }
  )];

  home.packages = [ wallpaper_changer ];

  wayland.windowManager.hyprland = let
    colors = config.lib.stylix.colors;
    hyprLua = import ../../../modules/user/hyprland/lua.nix { inherit lib; };
  in {
    settings = {
      config = {
        general = {
          gaps_in = 5;
          gaps_out = 5;
          border_size = 2;
          "col.active_border" = lib.mkForce {
            colors = [
              "rgba(${colors.base0C}ee)"
              "rgba(${colors.base0B}ee)"
            ];
            angle = 45;
          };
          "col.inactive_border" = lib.mkForce "rgba(${colors.base05}aa)";
          layout = "dwindle";
        };

        decoration = {
          border_part_of_window = false;
          rounding = 10;
          blur = {
            enabled = true;
            size = 16;
            passes = 2;
            new_optimizations = true;
          };
          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
          };
        };

        animations.enabled = true;
        dwindle.smart_split = true;
        master.new_status = "master";

        misc = {
          focus_on_activate = true;
          animate_manual_resizes = true;
          animate_mouse_windowdragging = true;
          enable_swallow = true;
        };
      };

      animation = [
        { leaf = "windows"; enabled = true; speed = 7; bezier = "myBezier"; }
        { leaf = "windowsOut"; enabled = true; speed = 7; bezier = "default"; style = "popin 80%"; }
        { leaf = "border"; enabled = true; speed = 10; bezier = "default"; }
        { leaf = "borderangle"; enabled = true; speed = 8; bezier = "default"; }
        { leaf = "fade"; enabled = true; speed = 7; bezier = "default"; }
        { leaf = "workspaces"; enabled = true; speed = 6; bezier = "default"; }
      ];

      curve = {
        _args = [
          "myBezier"
          {
            type = "bezier";
            points = [
              [ 0.05 0.9 ]
              [ 0.1 1.05 ]
            ];
          }
        ];
      };

      workspace_rule = [
        {
          workspace = "2";
          layout = "scrolling";
        }
      ];

      on = [
        (hyprLua.onStart [ "${lib.getExe wallpaper_changer}" ])
      ];

      bind = [
        (hyprLua.bind "SUPER + W" (hyprLua.exec "${lib.getExe wallpaper_changer}"))
        (hyprLua.bind "SUPER + SHIFT + S" (hyprLua.exec "${lib.getExe pkgs.grimblast} --notify --freeze copy area"))
        (hyprLua.bind "F11" (hyprLua.exec "ghostty -e sh -c hyprlock"))
      ];
    };
  };
}
