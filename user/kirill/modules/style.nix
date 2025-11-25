{ pkgs, config, lib, ... }: {
  stylix = {
    enable = true;
    targets = {
      hyprland.enable = false;
      waybar.enable = false;
    };

    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-city-dark.yaml";
    polarity = "dark";

    image = pkgs.fetchurl {
      url = "https://99px.ru/sstorage/53/2024/03/mid_357241_413672.jpg";
      sha256 = "sha256-evP7zstPa0ztNs/dUJ8G5p+/L2maIKZASeuONJ1C0h0=";
    };

    iconTheme = {
      enable = true;
      package = pkgs.pop-icon-theme;
      dark = "Pop-Dark";
    };

    cursor = {
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
      package = pkgs.catppuccin-cursors.mochaDark;
    };
 

    fonts = {
      monospace = {
        name = "JetBrains Mono";
        package = pkgs.jetbrains-mono;
      };

    serif = {
        name = "GabrieLa";
        package = (pkgs.google-fonts.override { fonts = [ "Gabriela" ]; });
      };

    emoji = {
        package = pkgs.noto-fonts-monochrome-emoji;
        name = "Noto Emoji";
      };

    sizes = {
        applications = 13;
        desktop = 12;
      };
    };

    opacity = {
      popups = .8;
      terminal = .5;
    };
  };

  xdg.configFile."helix/config.toml".text = ''theme = "catppuccin_mocha"'';
}
