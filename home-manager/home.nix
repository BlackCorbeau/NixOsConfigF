{config, pkgs, ...}: {
       imports = [
         ./zsh.nix
         ./data/pkgs.nix
       ];
 
       home = {
              username = "kirill";
              homeDirectory = "/home/kirill";
              stateVersion = "23.11";
       };
       programs.bash = {
              enable = true;
              shellAliases = {
                      rebuild = "sudo nixos-rebuild switch --flake ~/.config/f#usconfig";
                      deleteGenerations = "sudo nix-collect-garbage -d";
                      openHome = "vim .config/f/home-manager/home.nix";
                      rebuildHome = "home-manager switch --flake ~/.config/f";
                      openConfiguration = "sudo nano ~/.config/f/nixos/hosts/usconfig/configuration.nix";
                      openHyprland = "vim .config/f/home-manager/data/hyprland.nix";
                      openZSH = "vim .config/f/home-manager/zsh.nix";
                      openWayBar = "vim .config/home-manager/f/data/waybar.nix";
                      rebuildFlake = "sudo nixos-rebuild switch --flake /home/kirill/.config/f --impure";
                      openFlake = "vim /home/kirill/.config/f/flake.nix";
                      swichWalls = "python3 /nix/store/6czqsnf0gbvvm472lipndyg34qhnfpis-wallpaper_changer/bin/wallpaper_changer";
                      screenshot_f="grimblast save screen ~/screenshot_$(date +\%Y-\%m-\%d_\%H-\%M-\%S).png";
                      screenshot="grimblast save area ~/screenshot_$(date +\%Y-\%m-\%d_\%H-\%M-\%S).png";
              };
       };
}      
