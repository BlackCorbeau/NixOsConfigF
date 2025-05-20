{ config, ... }: {
  programs = {
  zoxide.enable = true;

  starship = {
      enable = true;
      enableZshIntegration = true;

      settings = {
        add_newline = true;
        format = ''
          $os$directory$git_branch$git_status
          $nix_shell$status$character
        '';
        right_format = "$all";

        cmake.disabled = true;
        cmd_duration = {
          format = "";
          show_notifications = true;
          notification_timeout = 10000;
        };
        git_branch.format = "on [$branch(:$remote_branch)]($style) ";
        git_metrics.disabled = false;
        git_status = {
          conflicted = "!";
          up_to_date = "ok";
          stashed = "S";
          modified = "M";
        };
        directory = {
          truncation_length = 3;
          fish_style_pwd_dir_length = 1;
          read_only = " RO";
        };
        nix_shell.format = "[nix-shell]($style) ";
        os.disabled = false;
        python = {
          symbol = "py ";
          python_binary = ["python3" "python"];
        };
        status.disabled = false;
      };
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      # enableAutosuggestions = true;
      syntaxHighlighting.enable = true;

      shellAliases =
        let
          flakeDir = "~/nix";
        in {
        rb = "sudo nixos-rebuild switch --flake ${flakeDir}";
        upd = "nix flake update ${flakeDir}";
        upg = "sudo nixos-rebuild switch --upgrade --flake ${flakeDir}";

        hms = "home-manager switch --flake ${flakeDir}";

        conf = "$EDITOR ${flakeDir}/nixos/hosts/$(hostname)/configuration.nix";
        pkgs = "$EDITOR ${flakeDir}/nixos/packages.nix";

        ll = "ls -l";
        se = "sudoedit";
        ff = "fastfetch";
        cat = "bat";
        cd = "z";

        rebuild = "sudo nixos-rebuild switch --flake ~/.config/f#usconfig";
        deleteGenerations = "sudo nix-collect-garbage -d";
        openHome = "vim .config/f/home-manager/home.nix";
        rebuildHome = "home-manager switch --flake ~/.config/f";
        rebuildHomeSudo = "sudo home-manager switch --flake ~/.config/f";
        openConfiguration = "sudo nano ~/.config/f/nixos/hosts/usconfig/configuration.nix";
        openHyprland = "vim .config/f/home-manager/data/hyprland.nix";
        openZSH = "vim .config/f/home-manager/zsh.nix";
        openWayBar = "vim .config/f/home-manager/data/waybar.nix";
        rebuildFlake = "sudo nixos-rebuild switch --flake /home/kirill/.config/f --impure";
        openFlake = "vim /home/kirill/.config/f/flake.nix";
        swichWalls = "python3 /nix/store/6czqsnf0gbvvm472lipndyg34qhnfpis-wallpaper_changer/bin/wallpaper_changer";
        screenshot_f="grimblast save screen ~/screenshot_$(date +\%Y-\%m-\%d_\%H-\%M-\%S).png";
        screenshot="grimblast save area ~/screenshot_$(date +\%Y-\%m-\%d_\%H-\%M-\%S).png";
        screenshot_c = "grimblast copy area";
        loginPostgresql = "sudo -u postgres psql";
        startShell = "nix-shell . --run zsh";
      };

      initExtra = ''
        if [ -z "''${WAYLAND_DISPLAY}" ] && [ "''${XDG_VTNR}" -eq 1 ]; then
          dbus-run-session Hyprland
        fi
        eval "$(zoxide init zsh)"
      '';

      history.size = 10000;
      history.path = "${config.xdg.dataHome}/zsh/history";

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "sudo" ];
        theme = "agnoster"; # blinks is also really nice
      };
    };
  };
}
