{ lib, inputs, hostname }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
    ../${hostname}/hardware-configuration.nix
    ../../modules/host.nix
    ./packages.nix
  ];

  options = {
    host = {
      laptop = lib.mkEnableOption "laptop mode";

      nvidia.prime = {
        enable = lib.mkEnableOption "NVIDIA PRIME offload for hybrid graphics";
        intelBusId = lib.mkOption {
          type = lib.types.str;
          default = "PCI:0:2:0";
          description = "Intel/iGPU Bus ID used by NVIDIA PRIME.";
        };
        nvidiaBusId = lib.mkOption {
          type = lib.types.str;
          default = "PCI:1:0:0";
          description = "NVIDIA dGPU Bus ID used by NVIDIA PRIME.";
        };
      };
    };
  };

  config = {
    networking.hostName = hostname;
    time.timeZone = lib.mkDefault "Europe/Moscow";
    i18n.defaultLocale = lib.mkDefault "ru_RU.UTF-8";
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    system.stateVersion = "24.05";
  };
}
