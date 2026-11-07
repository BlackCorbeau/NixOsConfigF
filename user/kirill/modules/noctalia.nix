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
      plugins = {
        enabled = [
          "avivbintangaringga/nix-monitor"
          "styrish/modernclock"
          "yahya637/process-monitor"
          "kirill/futuristic-clock"
          "kirill/system-dashboard"
        ];

        auto_update = "all";
      };

      plugin_settings = {
        # Process Monitor
        "yahya637/process-monitor" = {
          interval_ms = 2000;
          cpu_scale = "machine";
          rows_per_metric = 40;

          desktop_title = "System Monitor";
          desktop_rows = 8;
          desktop_sort = "overall";
          desktop_group_by_app = true;
          desktop_show_totals = true;
          desktop_show_graph = true;
          desktop_show_icons = true;
        };

        # Better Clock
        "yugaaank/better-clock" = {
          time_format = "{:%H:%M}";
          date_format = "{:%A, %d %B}";
          show_date = true;
        };

        # Nix Monitor
        "avivbintangaringga/nix-monitor" = {
          branch = "nixos-unstable";

          update_check_interval = 60;
          generation_check_interval = 60;
          system_stats_check_interval = 60;

          update_command =
            "cd ${config.home.homeDirectory}/.config/nixos && nix flake update nixpkgs";

          optimize_command = "nix-store --optimise -vv";

          # Не удаляем старые поколения
          clean_command = "nix-collect-garbage";
        };
      };

      system.monitor = {
        enabled = true;

        cpu_poll_seconds = 2.0;
        memory_poll_seconds = 2.0;
        network_poll_seconds = 3.0;
        disk_poll_seconds = 10.0;
      };

      desktop_widgets = {
        enabled = true;
        schema_version = 2;

        widget_order = [
          "cpu_graph"
          "ram_gauge"
          "network_graph"
          "gpu_graph"
        ];

        widget = {
          cpu_graph = {
            type = "sysmon";
            cx = 350.0;
            cy = 400.0;
            box_width = 400.0;
            box_height = 150.0;

            settings = {
              display = "graph";
              stat = "cpu_usage";
              color = "primary";
              show_label = true;
              background = true;
            };
          };

          ram_gauge = {
            type = "sysmon";
            cx = 350.0;
            cy = 600.0;
            box_width = 400.0;
            box_height = 100.0;

            settings = {
              display = "gauge";
              stat = "ram_pct";
              gauge_layout = "horizontal";
              color = "primary";
              show_label = true;
              background = true;
            };
          };

          network_graph = {
            type = "sysmon";
            cx = 1450.0;
            cy = 400.0;
            box_width = 440.0;
            box_height = 150.0;

            settings = {
              display = "graph";
              stat = "net_rx";
              stat2 = "net_tx";
              network_speed_unit = "auto";
              color = "primary";
              color2 = "secondary";
              show_label = true;
              background = true;
            };
          };

          gpu_graph = {
            type = "sysmon";
            cx = 1450.0;
            cy = 600.0;
            box_width = 440.0;
            box_height = 150.0;

            settings = {
              display = "graph";
              stat = "gpu_usage";
              color = "primary";
              show_label = true;
              background = true;
            };
          };
        };
      };

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

        start = [ "launcher" "workspaces" "keyboard_layout" "audio_visualizer" "nix_monitor" ];
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

      dock = {
        enabled = true;
        position = "bottom";

        # Размеры
        icon_size = 41;
        main_axis_padding = 12;
        cross_axis_padding = 8;
        item_spacing = 12;

        # Внешний вид
        background_opacity = 0.90;
        border_width = 0.0;
        shadow = true;
        radius = 40;
        margin_edge = 13;
        margin_ends = 0;

        # Поведение
        show_running = true;
        show_dots = true;
        show_instance_count = true;

        # Увеличение иконок
        magnification = true;
        magnification_scale = 1.45;
        active_scale = 1.0;
        inactive_scale = 0.85;

        # Динамическое скрытие
        auto_hide = false;
        smart_auto_hide = true;

        reserve_space = false;
        layer = "top";

        # Кнопка лаунчера
        launcher_position = "start";
        launcher_icon = "grid-dots";

        # Пока без постоянно закреплённых приложений
        pinned = [];
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

      widget.launcher = {
        custom_image =
          "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";

        custom_image_colorize = true;
      };

      widget.nix_monitor = {
        type = "avivbintangaringga/nix-monitor:nix-monitor";

        show_text = true;
        colorize_text = false;

        show_glyph = true;
        colorize_glyph = true;

        up_to_date_glyph = "rosette-discount-check";
        up_to_date_color = "#57ff57";

        checking_glyph = "loader-3";
        checking_color = "#ffeb57";

        update_available_glyph = "cloud-download";
        update_available_color = "#ff5757";

        unknown_glyph = "cloud-question";
        unknown_color = "on_surface";
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

  # Nix-managed local Noctalia plugins.
  home.file.".local/share/noctalia/plugins/futuristic-clock".source =
    ../../../modules/user/noctalia-plugins/futuristic-clock;

  home.file.".local/share/noctalia/plugins/system-dashboard".source =
    ../../../modules/user/noctalia-plugins/system-dashboard;

  home.packages = with pkgs; [
    brightnessctl
    cliphist
    ffmpeg
    grim
    imagemagick
    libnotify
    wf-recorder
    tesseract

    # Process Monitor
    python3
    procps
  ];
}