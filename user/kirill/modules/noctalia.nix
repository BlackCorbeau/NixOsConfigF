{ config, inputs, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors.withHashtag;
  system = pkgs.stdenv.hostPlatform.system;
in {
  imports = [ inputs.noctalia.homeModules.default ];

  # Noctalia uses the custom Stylix-derived palette below.
  # Disable Stylix's own Noctalia target to avoid conflicting definitions.
  stylix.targets.noctalia.enable = false;

  programs.noctalia = {
    enable = true;
    package = inputs.noctalia.packages.${system}.default;

    # Keep Noctalia's colors in sync with the existing Stylix Base16 scheme.

    customPalettes.Stylix = {
      dark = {
        # Tokyo City Dark / Lucid colors
        mPrimary = c.${config.stylix.accent};
        mOnPrimary = c.base00;

        mSecondary = c.base0D;
        mOnSecondary = c.base00;

        mTertiary = c.base0C;
        mOnTertiary = c.base00;

        mError = c.base08;
        mOnError = c.base00;

        # Surfaces
        mSurface = c.base00;
        mOnSurface = c.base05;

        mSurfaceVariant = c.base01;
        mOnSurfaceVariant = c.base04;

        mOutline = c.base01;
        mShadow = "#000000";

        mHover = c.base02;
        mOnHover = c.base05;

        terminal = {
          background = c.base00;
          foreground = c.base05;
          cursor = c.base05;
          cursorText = c.base00;
          selectionBg = c.base02;
          selectionFg = c.base05;

          normal = {
            black = c.base00;
            red = c.base08;
            green = c.base0B;
            yellow = c.base0A;
            blue = c.base0D;
            magenta = c.base0E;
            cyan = c.base0C;
            white = c.base05;
          };

          bright = {
            black = c.base03;
            red = c.base08;
            green = c.base0B;
            yellow = c.base0A;
            blue = c.base0D;
            magenta = c.base0E;
            cyan = c.base0C;
            white = c.base07;
          };
        };
      };
    };

    settings = {
      theme = {
        mode = "dark";
        source = "custom";
      };

      shell = {
        font_family = config.stylix.fonts.sansSerif.name;
        time_format = "{:%H:%M}";
        date_format = "%d.%m.%Y";
        telemetry_enabled = false;
        setup_wizard_enabled = false;
        polkit_agent = false; # plasma-polkit-agent is already started by Hyprland.
        # Enable Noctalia's own Win+V-style clipboard history panel.
        clipboard_enabled = true;
        clipboard_keep_from_closed_apps = true;
        clipboard_history_max_entries = 100;
        animation.enabled = true;
        animation.speed = 1.0;

        launcher = {
          layout = "full";
          default_view = "all";
        };

        panel = {
          transparency_mode = "soft";
          borders = true;
          border_color = "outline_variant";
          shadow = true;
          launcher_placement = "floating";
          clipboard_placement = "floating";
          control_center_placement = "attached";
          wallpaper_placement = "attached";
        };

        screenshot = {
          directory = "${config.home.homeDirectory}/screens";
          filename_pattern = "%Y-%m-%d_%H-%M-%S";
          save_to_file = true;
          copy_to_clipboard = true;
          format = "png";
        };
      };

      bar.default = {
        position = "top";
        enabled = true;
        reserve_space = true;
        layer = "top";
        thickness = 42;
        margin_ends = 10;
        margin_edge = 6;
        background_opacity = 0.90;
        compositor_blur = true;
        radius = 12;
        padding = 12;
        widget_spacing = 8;
        font_family = config.stylix.fonts.sansSerif.name;

        start = [ "workspaces" "keyboard_layout" "audio_visualizer" "weather" ];
        center = [ "media" ];
        end = [
          "network"
          "volume"
          "battery"
          "clock"
          "tray"
          "notifications"
          "control-center"
          "settings"
          "session"
        ];
      };

      widget.audio_visualizer = {
        bands = 14;
        width = 64;
        mirrored = true;
        centered = true;
        show_when_idle = false;
        color_1 = "primary";
        color_2 = "secondary";
      };

      widget.tray = {
        drawer = true;
        drawer_columns = 3;
        drawer_item_size = 24;
        detached_panel = true;
      };

      widget.clock.format = "{:%d %b - %H:%M}";

      location = {
        auto_locate = false;
        address = "Nizhny Novgorod, Russia";
      };

      weather = {
        enabled = true;
        refresh_minutes = 30;
        unit = "metric";
      };

      notification = {
        enable_daemon = true;
        position = "top_right";
        width = 360;
      };

      wallpaper = {
        enabled = true;
        directory = "${config.home.homeDirectory}/wallpapers";
        default.path = config.stylix.image;
        fill_mode = "crop";
        transition = [ "fade" "wipe" "zoom" ];
        transition_duration = 1200;
      };
    };
  };

  # Keep the small utilities used by existing screenshot/clipboard workflows.
  home.packages = with pkgs; [
    brightnessctl
    cliphist
    ffmpeg
    grim
    imagemagick
    libnotify
    wf-recorder
    tesseract
  ];
}