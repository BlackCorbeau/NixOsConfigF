{ pkgs, lib, ... }:
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
    ./host/zapret-config.nix
    ./host/network.nix
    #./host/ai-agent.nix
  ];

  programs = {
    dconf.enable = true;
    niri = {
      enable = true;
      # Keep Niri on the same nixpkgs as the rest of the system: the compositor
      # and the OpenGL/GBM driver stack must share one glibc/Mesa ABI. The old
      # nixos-26.05 Niri used glibc 2.42 + Mesa 26.0.3 while /run/opengl-driver
      # comes from unstable with glibc 2.44 + Mesa 26.2.6, which made opening
      # /dev/dri/card1 fail with EINVAL.
      package = pkgs.niri;
      useNautilus = false;
    };
  };

  # Niri must not intercept the physical power button; let logind power off.
  # Laptop-specific lid-switch behavior remains configured in the ThinkPad module.
  services.logind.settings.Login.HandlePowerKey = lib.mkDefault "poweroff";

  # Niri starts xwayland-satellite on demand when it is in PATH. It must come
  # from the same package set too, otherwise GBM/glamor fails there as well.
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  # Niri uses the GNOME portal backend for screencasting and GTK as the
  # fallback for file pickers and other desktop portal interfaces.
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-desktop-portal-termfilechooser
    ];
    config = {
      common.default = [ "gnome" "gtk" ];
      niri.default = [ "gnome" "gtk" ];
      # Keep the existing terminal file picker instead of requiring Nautilus.
      niri."org.freedesktop.impl.portal.FileChooser" = lib.mkForce [ "termfilechooser" ];
    };
  };

  # Required by Noctalia's built-in polkit agent.
  security.polkit.enable = true;

  # The NixOS niri module turns this on with mkDefault "as recommended by
  # upstream" for the Secret portal. Niri itself does not need it, and the
  # daemon prompts for the login keyring password at session start.
  services.gnome.gnome-keyring.enable = false;

  services = {
    udisks2.enable = true;
    fstrim.enable = true;
    upower.enable = true;
  };
  networking.networkmanager.enable = true;
}
