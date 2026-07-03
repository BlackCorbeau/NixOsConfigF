{ config, pkgs, ... }:{
  services.ollama = {
    enable = true;
    package = pkgs.ollama; # или ollama-cuda
  };
}
