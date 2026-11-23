{ pkgs, lib, config, host ? null, ... }:
let
  niriCfg = config.niriConfig;

  # Give the first tiled Ghostty terminal the whole workspace. When a second
  # terminal appears, shrink the first column and keep every new one at 50%.
  ghosttySmartLauncher = pkgs.writeShellApplication {
    name = "ghostty-smart-launch";
    runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.niri pkgs.util-linux ];
    text = ''
      GHOSTTY=${lib.escapeShellArg (lib.getExe config.programs.ghostty.package)}

      # Prevent two rapid Super+Enter presses from both being treated as first.
      lock_file="''${XDG_RUNTIME_DIR:-/tmp}/ghostty-smart-launch-''${UID}.lock"
      exec 9>"$lock_file"
      flock -x 9

      launch_without_layout_management() {
        flock -u 9 || true
        exec 9>&-
        exec "$GHOSTTY" "$@"
      }

      if ! workspace_id="$(niri msg --json workspaces | jq -er '.[] | select(.is_focused == true) | .id')"; then
        launch_without_layout_management "$@"
      fi

      if ! before_windows="$(niri msg --json windows)"; then
        launch_without_layout_management "$@"
      fi

      existing_ids="$(jq -c --argjson workspace_id "$workspace_id" '
        [
          .[]
          | select(.app_id == "com.mitchellh.ghostty")
          | select(.workspace_id == $workspace_id)
          | select(.is_floating != true)
          | .id
        ]
      ' <<< "$before_windows")"
      existing_count="$(jq -r 'length' <<< "$existing_ids")"
      first_id="$(jq -r 'if length == 1 then .[0] else empty end' <<< "$existing_ids")"

      # A workspace that already contains another app is not empty: the new
      # terminal must join it at 50%, even when this is the first Ghostty.
      workspace_has_other_windows="$(jq -r --argjson workspace_id "$workspace_id" '
        any(
          .[];
          .workspace_id == $workspace_id
          and .app_id != "com.mitchellh.ghostty"
        )
      ' <<< "$before_windows")"

      # Close the lock descriptor in Ghostty so the lock is released as soon
      # as its window appears, not when the terminal itself exits.
      ( exec 9>&-; exec "$GHOSTTY" "$@" ) >/dev/null 2>&1 &

      new_id=""
      for _ in $(seq 1 50); do
        current_windows="$(niri msg --json windows 2>/dev/null || printf '[]')"
        new_id="$(jq -r \
          --argjson workspace_id "$workspace_id" \
          --argjson existing_ids "$existing_ids" '
            [
              .[]
              | select(.app_id == "com.mitchellh.ghostty")
              | select(.workspace_id == $workspace_id)
              | select(.is_floating != true)
              | select((.id as $id | $existing_ids | index($id)) == null)
            ]
            | (map(select(.is_focused == true)) + .)
            | first
            | .id // empty
          ' <<< "$current_windows")"

        if [[ -n "$new_id" ]]; then
          break
        fi
        sleep 0.1
      done

      # A failed/slow launch must not resize an existing terminal needlessly.
      [[ -n "$new_id" ]] || exit 0

      if [[ "$existing_count" -eq 0 ]]; then
        niri msg action focus-window --id "$new_id"
        if [[ "$workspace_has_other_windows" == "true" ]]; then
          niri msg action set-column-width "50%"
        else
          niri msg action set-column-width "100%"
        fi
      else
        if [[ "$existing_count" -eq 1 && -n "$first_id" ]]; then
          niri msg action focus-window --id "$first_id"
          niri msg action set-column-width "50%"
        fi

        niri msg action focus-window --id "$new_id"
        niri msg action set-column-width "50%"
      fi
    '';
  };

  # Move the focused window to the other monitor, then into workspace N there.
  # With two outputs `next` toggles between them. `--focus false` keeps the
  # keyboard focus on the destination monitor after the window is placed.
  moveToOtherMonitorWorkspace =
    lib.concatStringsSep "\n" (lib.concatMap
      (n: let
        num = toString n;
        key = if n == 10 then "0" else num;
      in [
        ''Super+Alt+${key} hotkey-overlay-title="Move window to other monitor, workspace ${num}" { spawn-sh "${lib.getExe pkgs.niri} msg action move-window-to-monitor-next && ${lib.getExe pkgs.niri} msg action move-window-to-workspace --focus false ${num}"; }''
      ])
      (lib.range 1 10));

  # Each source module contributes Nix strings to niriConfig. This renderer
  # combines them into the single config.kdl consumed by Niri; no KDL source
  # files are kept in the repository.
  joinFragments = fragments:
    lib.concatStringsSep "\n\n" (lib.filter (fragment: fragment != "") fragments);

  section = name: body:
    lib.optionalString (body != "") "${name} {\n${body}\n}";

  configText = joinFragments [
    (section "input" (niriCfg.input or ""))
    (section "layout" (joinFragments [
      (niriCfg.layout or "")
      (niriCfg.layoutExtra or "")
    ]))
    (section "binds" (joinFragments [
      (niriCfg.binds or "")
      (niriCfg.bindsExtra or "")
    ]))
    (section "animations" (joinFragments [
      (niriCfg.animations or "")
      (niriCfg.animationsExtra or "")
    ]))
    (joinFragments [
      (niriCfg.windowRules or "")
      (niriCfg.windowRulesExtra or "")
    ])
    (niriCfg.blur or "")
    (niriCfg.outputs or "")
    (niriCfg.extra or "")
    (joinFragments [
      (niriCfg.startup or "")
      (niriCfg.startupExtra or "")
    ])
  ];

  # Validate with the exact Niri package the system runs. Using a different
  # package set here would validate against the wrong version/ABI.
  configFile = pkgs.writeText "niri-config.kdl" configText;
  checkedConfigFile = pkgs.runCommand "niri-config-checked" {
    nativeBuildInputs = [ pkgs.niri ];
  } ''
    niri validate --config ${configFile}
    cp ${configFile} "$out"
  '';
in
{
  imports = lib.optional
    (host != null && builtins.pathExists ../../host/${host.name}/modules/niri.nix)
    ../../host/${host.name}/modules/niri.nix;

  options.niriConfig = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    description = "Niri KDL fragments assembled from Nix modules.";
  };

  config = {
    niriConfig = {
      # Shared input defaults. The three-finger workspace gesture is native
      # to Niri; it switches workspaces vertically rather than horizontally.
      input = ''
        // Let systemd-logind handle the physical power key. Without this,
        // Niri intercepts it and suspends the machine regardless of logind.conf.
        disable-power-key-handling

        keyboard {
          xkb {
            layout "us,ru"
            options "grp:caps_toggle"
          }
          numlock
        }

        // Tap-to-click was implicit in Hyprland; Niri needs it enabled explicitly.
        // `dwt` avoids accidental taps while typing.
        touchpad {
          tap
          dwt
          accel-speed 0.0
        }
        mouse {
          accel-speed 0.0
        }
        trackpoint {
          accel-speed 0.0
        }

        // Natural scrolling remains disabled, as in the old Hyprland setup.
        focus-follows-mouse
      '';

      layout = ''
        center-focused-column "never"
        default-column-width { proportion 0.5; }
        preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
        }
      '';

      # Global bindings that do not depend on Noctalia or another user app.
      binds = ''
        // Terminal, file manager and clipboard TUI.
        Super+Return hotkey-overlay-title="Open terminal" { spawn "${ghosttySmartLauncher}/bin/ghostty-smart-launch"; }
        Super+E hotkey-overlay-title="Open file manager" { spawn "ghostty" "-e" "yazi"; }
        Super+V hotkey-overlay-title="Open clipboard history" { spawn "ghostty" "--title=clipse" "-e" "clipse"; }
        XF86Explorer hotkey-overlay-title="Open file manager" { spawn "ghostty" "-e" "yazi"; }

        // Window lifecycle and the Niri column layout.
        Super+Q hotkey-overlay-title="Close focused window" repeat=false { close-window; }
        Super+M hotkey-overlay-title="Exit Niri" { quit; }
        Super+F hotkey-overlay-title="Toggle floating window" { toggle-window-floating; }
        Super+J hotkey-overlay-title="Toggle tabbed column" { toggle-column-tabbed-display; }
        Super+Shift+F hotkey-overlay-title="Toggle fullscreen" { fullscreen-window; }

        Super+Left hotkey-overlay-title="Focus column left" { focus-column-left; }
        Super+Right hotkey-overlay-title="Focus column right" { focus-column-right; }
        Super+Up hotkey-overlay-title="Focus window above" { focus-window-up; }
        Super+Down hotkey-overlay-title="Focus window below" { focus-window-down; }

        // Two-monitor navigation. With two outputs, `next` toggles between them.
        Super+Tab hotkey-overlay-title="Switch to next monitor" { focus-monitor-next; }

        // Move the focused column horizontally or a window vertically.
        Super+Shift+Left hotkey-overlay-title="Move column left" { move-column-left; }
        Super+Shift+Right hotkey-overlay-title="Move column right" { move-column-right; }
        Super+Shift+Up hotkey-overlay-title="Move window up" { move-window-up; }
        Super+Shift+Down hotkey-overlay-title="Move window down" { move-window-down; }

        // Resize the current column or the focused window in its column.
        Super+Ctrl+Left hotkey-overlay-title="Decrease column width" { set-column-width "-60"; }
        Super+Ctrl+Right hotkey-overlay-title="Increase column width" { set-column-width "+60"; }
        Super+Ctrl+Up hotkey-overlay-title="Decrease window height" { set-window-height "-60"; }
        Super+Ctrl+Down hotkey-overlay-title="Increase window height" { set-window-height "+60"; }

        // Column consume/expel and overview (standard Niri defaults)
        Super+Comma hotkey-overlay-title="Consume or expel window left" { consume-or-expel-window-left; }
        Super+Period hotkey-overlay-title="Consume or expel window right" { consume-or-expel-window-right; }
        Super+O hotkey-overlay-title="Toggle overview" repeat=false { toggle-overview; }

        // Dynamic workspaces: numeric indexes do not pin empty named slots.
        // Niri creates the next empty workspace as windows are opened there.
        Super+1 hotkey-overlay-title="Switch to workspace 1" { focus-workspace 1; }
        Super+2 hotkey-overlay-title="Switch to workspace 2" { focus-workspace 2; }
        Super+3 hotkey-overlay-title="Switch to workspace 3" { focus-workspace 3; }
        Super+4 hotkey-overlay-title="Switch to workspace 4" { focus-workspace 4; }
        Super+5 hotkey-overlay-title="Switch to workspace 5" { focus-workspace 5; }
        Super+6 hotkey-overlay-title="Switch to workspace 6" { focus-workspace 6; }
        Super+7 hotkey-overlay-title="Switch to workspace 7" { focus-workspace 7; }
        Super+8 hotkey-overlay-title="Switch to workspace 8" { focus-workspace 8; }
        Super+9 hotkey-overlay-title="Switch to workspace 9" { focus-workspace 9; }
        Super+0 hotkey-overlay-title="Switch to workspace 10" { focus-workspace 10; }

        // Move just the focused window; keep the current workspace selected.
        Super+Shift+1 hotkey-overlay-title="Move window to workspace 1" { move-window-to-workspace focus=false 1; }
        Super+Shift+2 hotkey-overlay-title="Move window to workspace 2" { move-window-to-workspace focus=false 2; }
        Super+Shift+3 hotkey-overlay-title="Move window to workspace 3" { move-window-to-workspace focus=false 3; }
        Super+Shift+4 hotkey-overlay-title="Move window to workspace 4" { move-window-to-workspace focus=false 4; }
        Super+Shift+5 hotkey-overlay-title="Move window to workspace 5" { move-window-to-workspace focus=false 5; }
        Super+Shift+6 hotkey-overlay-title="Move window to workspace 6" { move-window-to-workspace focus=false 6; }
        Super+Shift+7 hotkey-overlay-title="Move window to workspace 7" { move-window-to-workspace focus=false 7; }
        Super+Shift+8 hotkey-overlay-title="Move window to workspace 8" { move-window-to-workspace focus=false 8; }
        Super+Shift+9 hotkey-overlay-title="Move window to workspace 9" { move-window-to-workspace focus=false 9; }
        Super+Shift+0 hotkey-overlay-title="Move window to workspace 10" { move-window-to-workspace focus=false 10; }

        // Send the focused window to the other monitor's workspace.
        ${moveToOtherMonitorWorkspace}

        // Workspace scroll and keyboard backlight.
        Super+WheelScrollDown hotkey-overlay-title="Switch to next workspace" cooldown-ms=150 { focus-workspace-down; }
        Super+WheelScrollUp hotkey-overlay-title="Switch to previous workspace" cooldown-ms=150 { focus-workspace-up; }
        Super+F3 hotkey-overlay-title="Increase keyboard backlight" { spawn-sh "brightnessctl -d '*::kbd_backlight' set +33%"; }
        Super+F2 hotkey-overlay-title="Decrease keyboard backlight" { spawn-sh "brightnessctl -d '*::kbd_backlight' set 33%-"; }

        // Audio and media keys.
        XF86AudioMute hotkey-overlay-title="Toggle audio mute" { spawn "pamixer" "-t"; }
        XF86AudioMicMute hotkey-overlay-title="Mute microphone" { spawn "pamixer" "--default-source" "-m"; }
        XF86AudioPlay hotkey-overlay-title="Play or pause media" { spawn "playerctl" "play-pause"; }
        XF86AudioPrev hotkey-overlay-title="Seek back 5 seconds" { spawn "playerctl" "position" "5-"; }
        XF86AudioNext hotkey-overlay-title="Seek forward 5 seconds" { spawn "playerctl" "position" "5+"; }
        Super+XF86AudioPrev hotkey-overlay-title="Previous media track" { spawn "playerctl" "previous"; }
        Super+XF86AudioNext hotkey-overlay-title="Next media track" { spawn "playerctl" "next"; }
        XF86AudioRaiseVolume hotkey-overlay-title="Increase volume" repeat=true { spawn "pamixer" "-i" "5"; }
        XF86AudioLowerVolume hotkey-overlay-title="Decrease volume" repeat=true { spawn "pamixer" "-d" "5"; }

        // Display brightness and shortcut inhibition.
        XF86MonBrightnessDown hotkey-overlay-title="Decrease screen brightness" { spawn "brightnessctl" "set" "5%-"; }
        XF86MonBrightnessUp hotkey-overlay-title="Increase screen brightness" { spawn "brightnessctl" "set" "+5%"; }
        Super+Escape hotkey-overlay-title="Toggle shortcut inhibition" allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

        // Show the complete configured keybind list on demand.
        Super+Shift+Slash hotkey-overlay-title="Show all keybinds" { show-hotkey-overlay; }

        XF86Mail hotkey-overlay-title="Open email client" { spawn "thunderbird"; }
        XF86WWW hotkey-overlay-title="Open web browser" { spawn "google-chrome-stable"; }
      '';

      windowRules = ''
        // Utility windows that were floating in the Hyprland setup.
        window-rule {
          match app-id=r#"^(imv|feh|mpv)$"#
          open-floating true
        }
        window-rule {
          match title="Список друзей"
          open-floating true
        }
        window-rule {
          match title="wifitui"
          open-floating true
        }
        window-rule {
          match title="pulsemixer"
          open-floating true
        }
        window-rule {
          match app-id="dragon-drop"
          open-floating true
        }
        window-rule {
          match title="clipse"
          open-floating true
          default-column-width { fixed 622; }
          default-window-height { fixed 652; }
        }
      '';

      extra = ''
        // Keep the hotkey overlay opt-in; open it with Super+Shift+Slash.
        hotkey-overlay {
          skip-at-startup
          hide-not-bound
        }
      '';

      startup = ''
        // Noctalia owns the polkit agent now; the old Plasma 5 unit is gone.
        spawn-at-startup "dbus-update-activation-environment" "--systemd" "--all"
        spawn-at-startup "systemctl" "--user" "import-environment" "PATH" "XDG_CURRENT_DESKTOP" "XDG_SESSION_DESKTOP" "XDG_SESSION_TYPE" "WAYLAND_DISPLAY" "DISPLAY" "GTK_USE_PORTAL" "QT_QPA_PLATFORMTHEME" "TDESKTOP_USE_GTK_FILE_DIALOG" "NIXOS_OZONE_WL" "ELECTRON_OZONE_PLATFORM_HINT" "XCURSOR_SIZE" "XCURSOR_THEME"
        spawn-at-startup "wl-clip-persist" "--clipboard" "both"
        spawn-at-startup "clipse" "-listen"
        spawn-at-startup "udiskie"
      '';
    };

    home.packages = with pkgs; [
      ghostty
      pamixer
      clipse
      cliphist
      wl-clipboard
      wl-clip-persist
      xclip
      brightnessctl
      playerctl
      udiskie
    ];

    home.sessionVariables = {
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "niri";
      XDG_CURRENT_DESKTOP = "niri";
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
      GTK_USE_PORTAL = "1";
      TDESKTOP_USE_GTK_FILE_DIALOG = "1";
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      XCURSOR_SIZE = toString config.stylix.cursor.size;
      XCURSOR_THEME = config.stylix.cursor.name;
      XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/screens";
    };

    xdg.configFile."niri/config.kdl".source = checkedConfigFile;
  };
}
