{ config, pkgs, ... }: let
  ghosttyWithGL = (config.lib.nixGL.wrap pkgs.ghostty);
  shaders = pkgs.fetchFromGitHub {
    owner = "sahaj-b";
    repo = "ghostty-cursor-shaders";
    rev = "06d4e90fb5410e9c4d0b3131584060adddf89406";
    hash = "sha256-G/UIr1bKnxn1AcHl/4FL/jou6b7M2VeREslYVELxdmw=";
  };
in {
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    package = ghosttyWithGL;

    settings = {
      confirm-close-surface = false;
      copy-on-select = false;
      title-report = true;
      # Match the old Hyprland terminal: neutral black with the original 0.78
      # transparency. The green tint is gone because the canvas is forced black
      # and Niri now draws the active border as an outline, not behind it.
      background = "000000";
      background-opacity = 0.78;
      background-blur = 28;

      custom-shader = "${shaders}/cursor_warp.glsl";
    };
  };
}
