# Noctalia's built-in lockscreen. This module is compositor-independent.
# It retains the existing background, clock, login box and fingerprint support.
{ config, lib, pkgs, ... }:
let
  noctalia = lib.getExe config.programs.noctalia.package;
  seq = lib.getExe' pkgs.coreutils "seq";
  sleep = lib.getExe' pkgs.coreutils "sleep";

  # Keep the previous behaviour where each fresh graphical session starts
  # locked. Niri brings up graphical-session.target; this service waits for
  # Noctalia's IPC before asking it to lock.
  lockOnStart = pkgs.writeShellScript "noctalia-lock-on-start" ''
    for _ in $(${seq} 1 150); do
      if ${noctalia} msg status >/dev/null 2>&1; then
        exec ${noctalia} msg session lock
      fi
      ${sleep} 0.2
    done
    exit 1
  '';

  # The existing lock-screen background image is retained.
  lockBackground = pkgs.fetchurl {
    name = "lock_background.png";
    url = "https://pibig.info/uploads/posts/2022-11/thumbs/1668799231_10-pibig-info-p-nyaya-oboi-11.png";
    hash = "sha256-cPq9Ef7bg+26k9IZ27RAm7UAEuGM+gxSX29hF46HapU=";
  };

  # Noctalia picks the first available output when a widget has no explicit
  # `output`, so every widget is declared per connected monitor.
  lockWidgetsFor = output: {
    "lockscreen-clock@${output}" = {
      type = "clock";
      inherit output;
      cx = 960.0;
      cy = 400.0;
      box_width = 520.0;
      box_height = 110.0;
      rotation = 0.0;
      # Reference monitor size Noctalia uses to translate `cx`/`cy` when the
      # layout is shown on a differently sized output. Without it Noctalia
      # treats the placement as unset and rewrites the layout on the first lock.
      placement_width = 1920.0;
      placement_height = 1080.0;
      settings = {
        clock_style = "digital";
        # Time first, then the date as day-month-year.
        format = "{:%H:%M:%S %d-%m-%Y}";
        color = "#c8c8c8";
        shadow = true;
        center_text = true;
        font_family = "Noto Sans";
      };
    };

    "lockscreen-login-box@${output}" = {
      type = "login_box";
      inherit output;
      cx = 960.0;
      cy = 898.0;
      box_width = 810.0;
      box_height = 196.0;
      rotation = 0.0;
      placement_width = 1920.0;
      placement_height = 1080.0;
      settings = {
        background_color = "#171d23";
        background_opacity = 0.88;
        background_radius = 12.0;
        center_password_text = false;
        input_opacity = 1.0;
        input_radius = 6.0;
        layout = "regular";
        show_caps_lock = true;
        show_keyboard_layout = true;
        show_login_button = true;
        show_media = true;
        show_media_controls = true;
        show_password_reveal = true;
        show_session_buttons = true;
        show_unlock_hint = true;
        show_weather = true;
      };
    };
  };

  lockWidgets = (lockWidgetsFor "eDP-1") // (lockWidgetsFor "HDMI-A-2");
in {
  # The widgets below are the defaults Noctalia starts from. Their on-screen
  # layout is meant to be adjusted with Noctalia's lockscreen widget editor
  # (`noctalia msg lockscreen-widgets-toggle-edit`), which persists the result
  # in ~/.local/state/noctalia/settings.toml — same workflow as the desktop
  # widgets in user/kirill/modules/noctalia.nix. That persisted layout wins
  # over this file; remove the `[lockscreen_widgets]` section from that state
  # file to reset to these values.

  systemd.user.services.noctalia-lock-on-start = {
    Unit = {
      Description = "Lock the Noctalia session when the graphical session starts";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lockOnStart}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.noctalia.settings = {
    lockscreen = {
      enabled = true;
      fingerprint = true;
      lock_before_suspend = true;
      allow_empty_password = false;
      grace_period_seconds = 0;

      # Keep the existing image and Noctalia tint configuration.
      wallpaper = "${lockBackground}";
      blurred_desktop = false;
      blur_intensity = 0.0;
      tint_color = "surface";
      tint_intensity = 0.3;

      # No animation: hyprlock appeared instantly, keep that behaviour.
      transition = [ ];
      transition_duration = 0;
    };

    lockscreen_widgets = {
      enabled = true;
      schema_version = 2;
      widget = lockWidgets;
      widget_order = builtins.attrNames lockWidgets;
    };
  };
}
