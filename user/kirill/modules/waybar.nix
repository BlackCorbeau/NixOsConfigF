{ osConfig, config, pkgs, lib, ... }: let
  c = config.lib.stylix.colors.withHashtag;

  # ---- Left edge power bar (separate waybar instance) ----
  leftWidth = 50;

  networkSpeed = pkgs.writeShellApplication {
    name = "network-speed";
    runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.iproute2 ];
    text = ''
      set -euo pipefail
      state=/tmp/waybar-network-speed

      iface=$(ip route show default | awk '{print $5; exit}')
      if [ -z "$iface" ]; then
        iface=$(awk 'NR > 2 && $1 != "lo:" { sub(":", "", $1); print $1; exit }' /proc/net/dev)
      fi
      [ -z "$iface" ] && exit 0

      read -r rx tx < <(awk -v i="$iface" '$1 ~ i":" { print $2, $10 }' /proc/net/dev)
      if [ -f "$state" ]; then
        read -r prx ptx ts < "$state"
        now=$(date +%s)
        dt=$((now - ts)); [ "$dt" -lt 1 ] && dt=1
        down=$(((rx - prx) / dt)); [ "$down" -lt 0 ] && down=0
        up=$(((tx - ptx) / dt)); [ "$up" -lt 0 ] && up=0
        echo " $(numfmt --to=iec --suffix=B/s "$down") $(numfmt --to=iec --suffix=B/s "$up")"
      fi
      printf '%s %s %s\n' "$rx" "$tx" "$(date +%s)" > "$state"
    '';
  };

  leftbarJson = {
    collapsed = pkgs.writeText "leftbar-collapsed.json" (builtins.toJSON {
      layer = "top";
      exclusive = false;
      position = "left";
      width = 1;
      spacing = 0;
      modules-left = [ "custom/hidden" ];
      modules-center = [ ];
      modules-right = [ ];
      "custom/hidden" = {
        format = "";
      };
    });

    expanded = pkgs.writeText "leftbar-expanded.json" (builtins.toJSON {
      layer = "top";
      exclusive = false;
      position = "left";
      width = leftWidth;
      spacing = 0;
      modules-left = [ "custom/network-speed" "disk" ];
      modules-center = [ ];
      modules-right = [ "custom/restart" "custom/power" ];
      "custom/power" = {
        format = "";
        on-click = "systemctl poweroff";
        tooltip = false;
      };
      "custom/restart" = {
        format = "";
        on-click = "systemctl reboot";
        tooltip = false;
      };
      "custom/network-speed" = {
        exec = "${lib.getExe networkSpeed}";
        interval = 2;
        rotate = 90;
        tooltip = false;
      };
      disk = {
        interval = 30;
        rotate = 90;
        format = "{percentage_free}%";
        paths = [ "/" ];
      };
    });
  };

  leftbarCss = {
    collapsed = pkgs.writeText "leftbar-collapsed.css" ''
      window#waybar {
        background: ${c.base0B};
        min-width: 1px;
      }
    '';

    expanded = pkgs.writeText "leftbar-expanded.css" ''
      window#waybar {
        background: transparent;
        min-width: ${toString leftWidth}px;
        font-family: "Symbols Nerd Font Mono", "Monocraft", "Font Awesome 7 Free";
        font-weight: bold;
        font-size: 1.3em;
      }

      #custom-power,
      #custom-restart,
      #custom-network-speed,
      #disk {
        background: ${c.base00};
        color: ${c.base05};
        border-radius: 6px;
        min-height: 34px;
        margin: 4px;
      }

      #custom-power:hover,
      #custom-restart:hover,
      #custom-network-speed:hover,
      #disk:hover {
        background: ${c.base0B};
        color: ${c.base00};
      }
    '';
  };

  leftbarHover = pkgs.writeShellApplication {
    name = "leftbar-hover";
    runtimeInputs = [ pkgs.coreutils pkgs.systemd ];
    text = ''
      set -euo pipefail
      hyprctl="${(config.wayland.windowManager.hyprland.package or pkgs.hyprland)}/bin/hyprctl"
      rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      json="$rt/leftbar.json"
      css="$rt/leftbar.css"
      state=collapsed

      cp -f "${leftbarJson.collapsed}" "$json"
      cp -f "${leftbarCss.collapsed}" "$css"

      while true; do
        pos="$($hyprctl cursorpos 2>/dev/null)" || pos=""
        x="''${pos%%,*}"
        if [ -n "$x" ]; then
          if [ "$state" != expanded ] && [ "$x" -ge 0 ] && [ "$x" -le 1 ]; then
            state=expanded
            cp -f "${leftbarJson.expanded}" "$json"
            cp -f "${leftbarCss.expanded}" "$css"
            systemctl --user restart waybar-left || true
          elif [ "$state" != collapsed ] && [ "$x" -gt ${toString leftWidth} ]; then
            state=collapsed
            cp -f "${leftbarJson.collapsed}" "$json"
            cp -f "${leftbarCss.collapsed}" "$css"
            systemctl --user restart waybar-left || true
          fi
        fi
        sleep 0.05
      done
    '';
  };
in {
  home.packages = with pkgs; [
    #Fonts
    font-awesome
    nerd-fonts.symbols-only
    monocraft
    
    #packages
    pulsemixer
    wifitui
    playerctl
    cava
  ];

  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.mainBar = {
      spacing = 8;

      modules-left = [
        "hyprland/workspaces"
        "hyprland/language"
        "keyboard-state"
        "cava"
        "custom/weather"
      ];

      modules-center = [
        "mpris"
      ];

      modules-right = [
        "group/system"
        "pulseaudio"
        "battery"
        "clock"
        "tray"
      ];

      cava = {
        bars = 14;
        sleep_timer = 5;
        hide_on_silence = true;
        bar_delimiter = 0;
        input_delay = 0;
        format-icons = [" " "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
      };

      clock = {
        tooltip = false;
        interval = 5;
        format = "{:L%d %b - %H:%M %a}";
      };

      pulseaudio = {
        format = "{icon}  {volume}%";
        format-icons = {
          headphone = "󰋋";
          hands-free = "";
          headset = "";
          phone = "";
          phone-muted = "󱂼";
          portable = "";
          car = "";
          default = ["󰕿" "󰖀" "󰖀" "󰕾" "󰕾"];
          muted = "󰕿";
        };
        on-click = "ghostty --title=pulsemixer -e pulsemixer";
      };

      mpris = {
        format = "{dynamic}";
        dynamic-len = 32;
        dynamic-order = [ "title" "artist" "album" ];
      };

      battery = {
        interval = 5;
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-icons = {
          default = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
          charging = ["󰢟" "󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅"];
        };
      };

      "keyboard-state" = {
        capslock = true;
        format = "{icon}";
        format-icons = {
          locked = "CAPS";
          unlocked = "";
        };
      };

      "hyprland/language" = {
        format-en = "en";
        format-ru = "ru";
      };


      "group/system" = {
        orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = false;
          };
          modules = [
            "network"
            "custom/mem"
            "cpu"
            "temperature"
          ];
      };

      network = {
        format = "{ifname}";
        format-wifi = " {essid} ({signalStrength}%)";
        format-ethernet = "{ifname}";
        format-disconnected = "";
        tooltip-format = "{ipaddr}";
        max-length = 50;
        on-click = "ghostty --title=wifitui -e wifitui";
      };

      "custom/weather" = let
        weather_script = pkgs.writers.writeBashBin "weather_script" {
        } /*sh*/ '' 
          #!/usr/bin/env bash
          for i in {1..5}
          do
              text=$(curl -s "https://wttr.in/$1?format=1")
              if [[ $? == 0 ]]
              then
                  text=$(echo "$text" | sed -E "s/\s+/ /g")
                  tooltip=$(curl -s "https://wttr.in/$1?format=4")
                  if [[ $? == 0 ]]
                  then
                      tooltip=$(echo "$tooltip" | sed -E "s/\s+/ /g")
                      echo "{\"text\":\"$text\", \"tooltip\":\"$tooltip\"}"
                      exit
                  fi
              fi
              sleep 2
          done
          echo "{\"text\":\"error\", \"tooltip\":\"error\"}"
        '';
      in {
        format = "{}";
        tooltip = true;
        interval = 1800;
        exec = "${pkgs.lib.getExe weather_script} Russia+Nizhnij+Novgorod";
        return-type = "json";
      };

      "custom/mem" = {
        format = "{} ";
        interval = 3;
        exec = "free -h | awk '/Mem:/{printf $3}'";
        tooltip = false;
      };

      cpu = {
        interval = 2;
        format = "{usage}% ";
        min-length = 6;
      };

      temperature = {
        hwmon-path = "/sys/class/hwmon/hwmon5/temp1_input";
        critical-threshold = 80;
        format = "{temperatureC}°C {icon}";
        format-icons = ["" "" "" "" ""];
        tooltip = false;
      };
    };

    style = let
      colors = config.lib.stylix.colors.withHashtag;
      radius = "6px";
      scssFile = pkgs.writeText "waybar.scss" /*scss*/ ''
        window#waybar {
          background: transparent;
          color: ${colors.base05};
          border-radius: ${radius};
          font-family: "Symbols Nerd Font Mono", "Monocraft", "Font Awesome 7 Free";
          font-weight: bold;
          font-size: .85em;

          & > * { padding: 8px; }
        }

        #cava,
        #language,
        #mpris,
        #pulseaudio,
        #network,
        #battery,
        #cpu,
        #temperature,
        #keyboard-state label.locked,
        #custom-mem,
        #clock,
        #custom-weather{
          background: ${colors.base00};
          border-radius: ${radius};
          padding: 8px;
        }

        #workspaces,
        #tray {
          background: ${colors.base00};
          border-radius: ${radius};
        }

        #workspaces button {
          color: ${colors.base05};
          padding: 4px;
          border-radius: ${radius};
          border: 1pt solid transparent;

          &:hover { background: ${colors.base01}; }

          &.active {
            background: ${colors.base0B};
            color: ${colors.base00};

            &:hover {
              border-color: ${colors.base0B};
              background: ${colors.base01};
              color: ${colors.base0B};
            }
          }
        }

        #mpris {
          &:hover { background: ${colors.base01}; }
          &.paused { opacity: .5; }
        }

        #tray {
          widget {
            border: 1pt solid transparent;
            border-radius: ${radius};
            &:hover { background: ${colors.base01}; }
            & > image { padding: 8px; }
          }

          & > .passive { border-color: ${colors.base02}; }
          & > .needs-attention { border-color: ${colors.base09}; }
        }

        #pulseaudio {
          &:hover { background: ${colors.base01}; }
          &.muted {
            background: ${colors.base08};
            color: ${colors.base00};

            &:hover {
              color: ${colors.base08};
              background: ${colors.base01};
            }
          }
        }

        #network {
          &:hover { background: ${colors.base01}; }
          &.disconnected {
            color: ${colors.base00};
            background: ${colors.base08};
          }
        }

        #system .drawer-child > * {
          margin-right: 4px
        }

        #keyboard-state label.locked {
          background-color: ${colors.base00};
          color: ${colors.base08};
        }

        #battery {
          &.plugged { color: ${colors.base0D}; }
          &.charging { color: ${colors.base0B}; }
          &:not(.charging) {
            &.warning {
              color: ${colors.base00};
              background-color: ${colors.base09};
            }
            &.critical {
              background-color: ${colors.base08};
              color: ${colors.base00};
              animation-name: blink;
              animation-duration: 0.5s;
              animation-timing-function: linear;
              animation-iteration-count: infinite;
              animation-direction: alternate;
            }
          }
          &.full {
            color: ${colors.base00};
            background: ${colors.base0B};
          }
        }

      	@keyframes blink {
          to {
            background-color: ${colors.base00};
            color: ${colors.base08};
          }
        }
      '';

      cssFile = pkgs.runCommand "waybar.css" {
        nativeBuildInputs = [ pkgs.dart-sass ];
      } "sass ${scssFile} $out";
    in builtins.readFile cssFile;
  };

  # Left edge bar: own waybar instance with its own config/style,
  # toggled between 1px accent strip and 8px button bar by the hover daemon.
  xdg.configFile."waybar/leftbar-collapsed.json".source = leftbarJson.collapsed;
  xdg.configFile."waybar/leftbar-expanded.json".source = leftbarJson.expanded;
  xdg.configFile."waybar/leftbar-collapsed.css".source = leftbarCss.collapsed;
  xdg.configFile."waybar/leftbar-expanded.css".source = leftbarCss.expanded;

  systemd.user.services.waybar-left = {
    Unit = {
      Description = "Waybar left edge bar";
      After = [ "waybar-left-hover.service" ];
      Wants = [ "waybar-left-hover.service" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.waybar} -c %t/leftbar.json -s %t/leftbar.css";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.waybar-left-hover = {
    Unit.Description = "Waybar left edge bar hover daemon";
    Service = {
      ExecStart = "${lib.getExe leftbarHover}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };

}
