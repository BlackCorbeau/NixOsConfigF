{ config, lib, pkgs, ... }:

lib.mkIf config.services.printing.enable {
  services = {
    printing.drivers = with pkgs; [
      brlaser
    ];

    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };

  hardware.sane = {
    enable = true;
    extraBackends = with pkgs; [ sane-airscan ];
  };

  environment.systemPackages = with pkgs; [
    # sane-frontends is the old GTK2 frontend and gtk2 is marked broken in
    # current nixpkgs.  scanimage/saned are provided by sane-backends through
    # hardware.sane.enable; simple-scan covers the GUI.
    simple-scan
  ];
}
