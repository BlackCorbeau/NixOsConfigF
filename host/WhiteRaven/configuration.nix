# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, pkgs, pkgs-stable, lib, inputs,  ... }:

{
  imports = [
      ./modules/grab.nix

    (import ../modules/common.nix {
      inherit lib;
      inherit inputs;
      hostname = "WhiteRaven";
    })

    (import ../../user/common.nix {
      inherit config;
      inherit pkgs;
      inherit pkgs-stable;
      inherit lib;
      inherit inputs;
      name = "kirill";
      fullname = "Black Raven";
    })
  ];

  hardware.bluetooth.enable = true;
}
