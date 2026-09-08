{ pkgs, ... }:
{
  imports = [
    ./host/bluetooth.nix
    ./host/bootloader.nix
    ./host/env.nix
    ./host/sound.nix
    ./host/vpn.nix
    ./host/postgresql.nix
    ./host/gamemode.nix
    ./host/printing.nix
    #./host/zapret-config.nix
    ./host/network.nix
    #./host/ai-agent.nix
  ];

  programs = {
    dconf.enable = true;
    hyprland.enable = true;
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
      xdg-desktop-portal-termfilechooser
    ];
    config = {
      common.default = [ "hyprland" "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };
  services = {
    udisks2.enable = true;
    fstrim.enable = true;
    upower.enable = true;
  };
  networking.networkmanager.enable = true;
}
