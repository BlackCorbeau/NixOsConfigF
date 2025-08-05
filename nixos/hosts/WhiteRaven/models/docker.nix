{config, pkgs, ... }:{
  virtualisation.docker = {
  enable = true;
  # Set up resource limits
  daemon.settings = {
    experimental = true;
    };
  };
}
