{ config, lib, pkgs, ... }: {
  hardware = {
    enableRedistributableFirmware = true;

    trackpoint = {
      enable = true;
      emulateWheel = true;
    };
  };

  powerManagement.enable = true;

  services = {
    fwupd.enable = true;
    thermald.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
      HandlePowerKey = "poweroff";
    };

    tlp = {
      enable = true;

      settings = {
        START_CHARGE_THRESH_BAT0 = 70;
        STOP_CHARGE_THRESH_BAT0 = 95;
        START_CHARGE_THRESH_BAT1 = 70;
        STOP_CHARGE_THRESH_BAT1 = 85;
        RESTORE_THRESHOLDS_ON_BAT = 1;

        AHCI_RUNTIME_PM_ON_AC = "on";
        AHCI_RUNTIME_PM_ON_BAT = "auto";
        SATA_LINKPWR_ON_AC = "med_power_with_dipm";
        SATA_LINKPWR_ON_BAT = "med_power_with_dipm";

        USB_AUTOSUSPEND = 1;
      };
    };
  };

  networking.networkmanager.wifi.powersave = true;

  environment.systemPackages = with pkgs; [
    acpi
    lm_sensors
    pciutils
    powertop
    smartmontools
    usbutils
    nvme-cli
  ];
}
