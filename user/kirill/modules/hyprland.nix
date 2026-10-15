{ pkgs, lib, config, inputs, host, ... }:
let
  wallpaper_changer = pkgs.writers.writePython3Bin "wallpaper_changer" {
    libraries = [ pkgs.python3Packages.requests ];
    flakeIgnore = [ "E111" "E121" "E241" "E501" "E701" "E731" ];
  } /*py*/ ''
    import requests as requests
    from random import choice
    from os import listdir, makedirs, remove, replace, system
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


    folder = "${config.home.homeDirectory}/wallpapers"
    url = "https://wallhaven.cc/api/v1/collections/BlackRaven21/2284568"

    filename = None
    notify("Updating wallpaper...", 0)

    try:
      response = requests.get(url, timeout=10)
      response.raise_for_status()
      json = response.json()

      wallpaper = choice(json['data'])
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

    except requests.exceptions.RequestException:
      notify("Offline mode")
      try:
        filename = choice(listdir(folder))
      except (FileNotFoundError, IndexError):
        notify("Offline mode and wallpaper cache is empty")

    finally:
      if filename is not None:
        notify("Applying wallpaper", 100)
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
