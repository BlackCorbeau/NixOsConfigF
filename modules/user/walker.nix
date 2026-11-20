{ ... }:
{
  services = {
    walker = {
      enable = true;
      systemd.enable = true;
    };

    elephant.enable = true;
  };
}
