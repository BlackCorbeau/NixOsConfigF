{ config, inputs, pkgs, ... }: {
  imports = [ inputs.ags.homeManagerModules.default ];

  programs.ags = {
    enable = true;

    configDir = null;

    extraPackages = with inputs.ags.packages.${pkgs.system}; [
      battery
      mpris
      hyprland
      network
      tray
      wireplumber
    ];
  };

  home.packages = with pkgs; [
    pulsemixer
  ];

  wayland.windowManager.hyprland.settings.exec-once = [ "ags run" ];

  xdg.configFile."ags".source = (pkgs.callPackage ./ags/ags.nix { colors = config.lib.stylix.colors; });
}
