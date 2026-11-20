{ pkgs, lib, config, inputs, ... }:

let
  colors = config.lib.stylix.colors;
  secretPath = config.sops.secrets."tokens/apis/wallhaven".path;

  # Wait until Noctalia's IPC and notification service are ready before the
  # Wallhaven job starts. Noctalia owns org.freedesktop.Notifications.
  noctaliaExe = lib.getExe inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  waitForNotifications = pkgs.writeShellScript "wait-for-notifications" ''
    for _ in $(${pkgs.coreutils}/bin/seq 1 100); do
      if ${noctaliaExe} msg status >/dev/null 2>&1 && \
        ${lib.getExe' pkgs.dbus "dbus-send"} \
          --session --dest=org.freedesktop.DBus --type=method_call --print-reply \
          /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
          string:org.freedesktop.Notifications 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep -q 'boolean true'; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.2
    done
    exit 0
  '';

  wallpaper_changer = pkgs.writers.writePython3Bin "wallpaper_changer" {
    libraries = [ pkgs.python3Packages.requests ];
    flakeIgnore = [ "E111" "E121" "E241" "E501" "E701" "E731" ];
  } /*py*/ ''
    import requests as requests
    from random import choice
    from os import environ, getuid, listdir, makedirs, remove, replace
    from os.path import exists, getmtime, isfile
    from subprocess import run

    notify_id = None


    def notify(text, progress=None, expire_time=5000):
      global notify_id

      command = [
        "${pkgs.libnotify}/bin/notify-send",
        "--app-name", "wallpaper_changer",
        "--print-id",
        "--expire-time", str(expire_time),
      ]

      if notify_id:
        command.extend(["--replace-id", str(notify_id)])

      if progress is not None:
        command.extend(["--hint", f"int:value:{progress}"])

      command.extend(["Wallpaper", text])

      result = run(command, capture_output=True, text=True, check=False)
      output = result.stdout.strip()
      if output.isdigit():
        notify_id = output


    def download_with_progress(link, destination):
      temporary = f"{destination}.part"
      downloaded = 0
      last_progress = -1

      response = None
      try:
        response = requests.get(link, stream=True, timeout=30)
        response.raise_for_status()
        total = int(response.headers.get("content-length", 0))

        with open(temporary, "wb") as file:
          for chunk in response.iter_content(chunk_size=256 * 1024):
            if not chunk:
              continue

            file.write(chunk)
            downloaded += len(chunk)

            if total <= 0:
              continue

            progress = min(100, downloaded * 100 // total)
            if progress == 100 or progress >= last_progress + 2:
              notify(f"Downloading... {progress}%", progress, 0)
              last_progress = progress

        replace(temporary, destination)
      except Exception:
        if exists(temporary):
          remove(temporary)
        raise
      finally:
        if response is not None:
          response.close()


    def prune(folder, keep=20):
      files = [
        (name, getmtime(f"{folder}/{name}"))
        for name in listdir(folder)
        if isfile(f"{folder}/{name}") and not name.endswith(".part")
      ]

      if len(files) <= keep:
        return

      for name, _ in sorted(files, key=lambda item: item[1])[:len(files) - keep]:
        remove(f"{folder}/{name}")


    def read_history(path):
      try:
        with open(path) as file:
          return [line.strip() for line in file if line.strip()]
      except OSError:
        return []


    def write_history(path, ids):
      try:
        with open(path, "w") as file:
          file.write("\n".join(dict.fromkeys(ids)) + "\n")
      except OSError:
        pass


    folder = "${config.home.homeDirectory}/wallpapers"
    url = "https://wallhaven.cc/api/v1/collections/BlackRaven21/2284568"
    runtime = environ.get("XDG_RUNTIME_DIR") or f"/run/user/{getuid()}"
    history = f"{runtime}/wallpaper_changer_history"

    token = None
    try:
      with open("${secretPath}") as file:
        token = file.read().strip() or None
    except OSError:
      pass

    filename = None
    notify("Updating wallpaper...", 0)

    try:
      params = {}
      if token:
        params["apikey"] = token

      response = requests.get(url, params=params, timeout=10)
      response.raise_for_status()
      page_json = response.json()

      walls = list(page_json['data'])
      for page in range(2, page_json['meta']['last_page'] + 1):
        params['page'] = page
        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()
        walls.extend(response.json()['data'])

      seen = read_history(history)
      candidates = [wall for wall in walls if wall['id'] not in seen]

      if not candidates:
        seen = []
        candidates = walls

      wallpaper = choice(candidates)
      link = wallpaper['path']
      format = wallpaper['file_type']
      id = wallpaper['id']

      if format == "image/jpeg": ext = "jpg"
      else:                      ext = "png"

      filename = f"{id}.{ext}"
      destination = f"{folder}/{filename}"

      if not exists(destination):
        makedirs(folder, exist_ok=True)
        notify("Downloading... 0%", 0, 0)
        download_with_progress(link, destination)
        notify("Downloaded", 100)
        prune(folder)
      else:
        notify("Using cached wallpaper", 100)

      write_history(history, seen + [id])

    except requests.exceptions.RequestException:
      notify("Offline mode")
      try:
        filename = choice(listdir(folder))
      except (FileNotFoundError, IndexError):
        notify("Offline mode and wallpaper cache is empty")

    finally:
      if filename is not None:
        notify("Applying wallpaper", 100)
        run([
          "${noctaliaExe}",
          "msg",
          "wallpaper-set",
          f"{folder}/{filename}",
        ], check=False)
  '';
in {
  imports = [ ../../../modules/user/niri.nix ];

  # Kirill's Noctalia-specific Niri configuration, merged into the shared
  # sections by modules/user/niri.nix.
  niriConfig = {
    layoutExtra = ''
      // Niri's single gaps value covers both inner and outer spacing.
      // This carries over the old 5px Hyprland inner/outer gaps.
      gaps 5

      focus-ring {
        off
      }

      // Match Hyprland: green active accent and a subtle inactive outline.
      border {
        on
        width 2
        active-color "#${colors.base0B}ee"
        inactive-color "#${colors.base05}aa"
        urgent-color "#${colors.base08}ee"
      }

      shadow {
        off
      }
    '';

    bindsExtra = ''
      // Noctalia launcher, panels and editing shortcuts.
      Super+D hotkey-overlay-title="Open app launcher" { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
      Super+Shift+D hotkey-overlay-title="Edit desktop widgets" { spawn "noctalia" "msg" "desktop-widgets-toggle-edit"; }
      Super+Shift+L hotkey-overlay-title="Edit lock screen widgets" { spawn "noctalia" "msg" "lockscreen-widgets-toggle-edit"; }
      Super+Shift+G hotkey-overlay-title="Open control center" { spawn "noctalia" "msg" "panel-toggle" "control-center"; }
      Super+W hotkey-overlay-title="Download next Wallhaven wallpaper" { spawn "${lib.getExe wallpaper_changer}"; }
      Super+Shift+W hotkey-overlay-title="Open wallpaper selector" { spawn "noctalia" "msg" "panel-toggle" "wallpaper"; }
      Super+Shift+V hotkey-overlay-title="Open clipboard history" { spawn "noctalia" "msg" "panel-toggle" "clipboard"; }

      // Screenshot workflow and lock screen.
      Print hotkey-overlay-title="Capture selected screen area" { spawn "noctalia" "msg" "screenshot-region"; }
      Super+Print hotkey-overlay-title="Capture full screen" { spawn "noctalia" "msg" "screenshot-fullscreen"; }
      Ctrl+Print hotkey-overlay-title="Capture area with annotation" { spawn "noctalia" "msg" "screenshot-region" "--annotate"; }
      Alt+Print hotkey-overlay-title="Capture focused window" { spawn "noctalia" "msg" "screenshot-window"; }
      Super+Shift+S hotkey-overlay-title="Capture area to clipboard only" { spawn "noctalia" "msg" "screenshot-region" "--no-annotate" "--copy-to-clipboard" "--no-save-to-file"; }
      F11 hotkey-overlay-title="Lock the session" { spawn "noctalia" "msg" "session" "lock"; }

    '';

    windowRulesExtra = ''
      // Slightly dim inactive windows, as in the previous Hyprland setup.
      window-rule {
        match is-active=false
        opacity 0.95
      }

      // Preserve rounded corners and the Hyprland-style live background blur.
      // xray=false blurs what is actually behind the window, like Hyprland did.
      window-rule {
        geometry-corner-radius 10
        clip-to-geometry true
        background-effect {
          xray false
          blur true
        }
      }

      // Keep the 10px Hyprland rounding on focused and unfocused windows.
      // Give Ghostty the same live-content blur as the old Hyprland setup.
      // xray=false blurs live windows behind the terminal, not just wallpaper.
      window-rule {
        match app-id="com.mitchellh.ghostty"
        // Draw the green active border as an outline, not as a solid layer
        // behind Ghostty's translucent background.
        draw-border-with-background false
        background-effect {
          blur true
          xray false
        }
      }
    '';

    blur = ''
      // Match the old Hyprland blur: decoration.size = 28 with 2 passes.
      // Niri's dual-kawase radius grows with passes * offset; 3 * 4 gives a
      // comparably wide, smooth blur without the artifacts of a huge offset.
      blur {
        passes 3
        offset 4.0
        noise 0.02
        saturation 1.0
      }
    '';

    animations = ''
      workspace-switch {
        spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
      }

      horizontal-view-movement {
        spring damping-ratio=1.0 stiffness=900 epsilon=0.0001
      }

      window-open {
        duration-ms 140
        curve "ease-out-expo"
      }

      window-close {
        duration-ms 130
        curve "ease-out-quad"
      }

      window-movement {
        spring damping-ratio=1.0 stiffness=900 epsilon=0.0001
      }

      window-resize {
        spring damping-ratio=1.0 stiffness=900 epsilon=0.0001
      }

      screenshot-ui-open {
        duration-ms 140
        curve "ease-out-quad"
      }
    '';

    startupExtra = ''
      spawn-at-startup "noctalia"
    '';
  };

  home.packages = [ wallpaper_changer ];

  # One wallpaper refresh per Niri graphical session. The script downloads
  # the next item from the same Wallhaven collection, keeps the local cache,
  # and asks Noctalia to apply the result.
  systemd.user.services.wallpaper-changer = {
    Unit = {
      Description = "Download and apply a Wallhaven wallpaper";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${waitForNotifications}";
      ExecStart = "${lib.getExe wallpaper_changer}";
      TimeoutStartSec = "5min";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

}
