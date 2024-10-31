{ config, ... }: {
  programs.zoxide.enable = true;
  programs.zsh = {
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
      rebuildHomeImpure = "home-manager switch --flake ~/.config/f --impure";
      openConfiguration = "sudo nano ~/.config/f/nixos/hosts/usconfig/configuration.nix";
      openHyprland = "vim .config/f/home-manager/data/hyprland.nix";
      openZSH = "vim .config/f/home-manager/zsh.nix";
      openWayBar = "vim .config/f/home-manager/data/waybar.nix";
      rebuildFlake = "sudo nixos-rebuild switch --flake /home/kirill/.config/f --impure";
      openFlake = "vim /home/kirill/.config/f/flake.nix";
      swichWalls = "python3 /nix/store/6czqsnf0gbvvm472lipndyg34qhnfpis-wallpaper_changer/bin/wallpaper_changer";
      screenshot_f="grimblast save screen ~/screenshot_$(date +\%Y-\%m-\%d_\%H-\%M-\%S).png";
      screenshot="grimblast save area ~/screenshot_$(date +\%Y-\%m-\%d_\%H-\%M-\%S).png";
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
}
