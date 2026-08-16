{ config, pkgs, lib, ... }: let
  primeCfg = config.host.nvidia.prime;
in {
  config = lib.mkIf primeCfg.enable {
    boot = {
      kernelParams = [ "nvidia-drm.modeset=1" ];
      initrd.kernelModules = [ "i915" ];
    };

    services.xserver.videoDrivers = [ "modesetting" "nvidia" ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };

      nvidia = {
        modesetting.enable = true;

        powerManagement = {
          enable = true;
          finegrained = false;
        };

        open = false;
        nvidiaSettings = true;

        package = config.boot.kernelPackages.nvidiaPackages.legacy_470;

        prime = {
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };

          intelBusId = primeCfg.intelBusId;
          nvidiaBusId = primeCfg.nvidiaBusId;
        };
      };
    };

    environment.sessionVariables = {
      __GL_VRR_ALLOWED = 1;
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      NIXOS_OZONE_WL = 1;
    };

    environment.shellAliases = {
      nvidia-offload = "__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia";
    };
  };
}