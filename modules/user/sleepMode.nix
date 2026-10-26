{ config, pkgs, lib, ... }:
let
  hyprLua = import ./hyprland/lua.nix { inherit lib; };

  hyprlock = lib.getExe pkgs.hyprlock;
  hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";
  loginctl = lib.getExe' pkgs.systemd "loginctl";
  pidof = lib.getExe' pkgs.procps "pidof";
in {
  wayland.windowManager.hyprland.settings.on = [ (hyprLua.onStart [ "hyprlock" ]) ];

  # Hypridle listens to logind's PrepareForSleep signal: it locks the session
  # before suspend and makes sure hyprlock is running (and the display is on)
  # after resume.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${pidof} hyprlock >/dev/null || ${hyprlock}";
        before_sleep_cmd = "${loginctl} lock-session";
        after_sleep_cmd = "${pidof} hyprlock >/dev/null || ${hyprlock} & ${hyprctl} dispatch 'hl.dsp.dpms({action = \"on\"})'";
      };

      # Hypridle requires at least one listener, so keep a no-op timer that
      # practically never fires. Screen locking is driven by sleep/resume only.
      listener = [
        {
          timeout = 604800; # 7 days
          on-timeout = "";
        }
      ];
    };
  };

  programs.hyprlock = let
    image = pkgs.fetchurl {
      name = "lock_background.png";
      url = "https://pibig.info/uploads/posts/2022-11/thumbs/1668799231_10-pibig-info-p-nyaya-oboi-11.png";
      hash = "sha256-cPq9Ef7bg+26k9IZ27RAm7UAEuGM+gxSX29hF46HapU=";
    };
  in {
    enable = true;

    settings = {
      # Hyprlock's built-in fingerprint support watches logind's
      # PrepareForSleep signal and re-arms itself after resume.  PAM-based
      # fingerprint auth (security.pam.services.hyprlock.fprintAuth) does not
      # survive the fingerprint device being reset during suspend.
      auth.fingerprint = {
        enabled = true;
        ready_message = "Scan fingerprint to unlock";
        present_message = "Scanning...";
        retry_delay = 250;
      };

      background = {
        path = lib.mkForce "${image}";
        blur_passes = 0;
        blur_size = 7;
        noise = 0.0117;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      shape = {
        size = "360, 60";
        color = "rgba(17, 17, 17, 1.0)";
        rounding = -1;
        border_size = 3;
        border_color = "rgba(0, 207, 230, 1.0)";
        rotate = 0;
        xray = false;

        position = "750, -300";
        halign = "center";
        valign = "center";
        };

     label = {
        text = "Hi there, $USER";
        text_align = "center";
        color = "rgba(200, 200, 200, 1.0)";
        font_size = 25;
        font_family = "Noto Sans";
        rotate = 0;

        position = "750, -300";
        halign = "center";
        valign = "center";
      };

      DTlabel = {
        text = "$(date +'%Y-%m-%d %H:%M:%S')";
        text_align = "center";
        color = "rgba(200, 200, 200, 1.0)";
        font_size = 20;
        font_family = "Noto Sans";
        rotate = 0;

        position = "750, -200";
        halign = "center";
        valign = "center";
      };

      input-field = {
        size = "200, 50";
        outline_thickness = 3;
        dots_size = 0.33;
        dots_spacing = 0.15;
        dots_center = false;
        dots_rounding = -1;
        dots_fade_time = 200;
        # outer_color = "rgb(151515)";
        # inner_color = "rgb(200, 200, 200)";
        # font_color = "rgb(10, 10, 10)";
        font_family = "Noto Sans";
        fade_on_empty = true;
        fade_timeout = 1000;
        placeholder_text = "<i>Input Password...</i>";
        hide_input = false;
        rounding = -1;
        # check_color = "rgb(204, 136, 34)";
        # fail_color = "rgb(204, 34, 34)";
        fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
        fail_timeout = 2000;
        fail_transition = 300;
        capslock_color = -1;
        numlock_color = -1;
        bothlock_color = -1;
        invert_numlock = false;
        swap_font_color = false;

        position = "750, -400";
        halign = "center";
        valign = "center";
      };
    };
  };
}
