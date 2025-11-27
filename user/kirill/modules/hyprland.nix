{ pkgs, lib, config, inputs, ... }: {
  imports = [(
    import ../../../modules/user/hyprland.nix {
      inherit lib;
      inherit pkgs;
      inherit config;
      inherit inputs;
      swww_flags = "--transition-type center";
    }
  )];

  wayland.windowManager.hyprland = let
    colors = config.lib.stylix.colors;
  in {
    settings = {
      monitor = ",preferred,auto,1";

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 3;
        "col.active_border" = lib.mkForce "rgba(${colors.base0C}ee) rgba(${colors.base0B}ee) 45deg";
        "col.inactive_border" = lib.mkForce "rgba(${colors.base05}aa)";

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

        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
        };
      };

      animations = {
        enabled = true;

        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

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
        pseudotile = true;
        smart_split = true;
      };

      master.new_status = "master";

      misc = {
        animate_manual_resizes = true;
        animate_mouse_windowdragging = true;
        enable_swallow = true;
      };

      bind = [
        ''$mainMod Shift, S, exec, grimblast --notify --freeze copy area''
        '', F11, exec, ghostty -e sh -c "hyprlock"''
      ];
    };
  };
}
