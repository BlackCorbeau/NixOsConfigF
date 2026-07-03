{
  imports = [
    ./host/bluetooth.nix
    ./host/bootloader.nix
    ./host/env.nix
    ./host/sound.nix
    ./host/vpn.nix
    ./host/postgresql.nix
    #./host/zapret-config.nix
    ./host/network.nix
    #./host/ai-agent.nix
  ];

  programs.hyprland.enable = true;
  services = {
    udisks2.enable = true;
    fstrim.enable = true;
    upower.enable = true;
  };
  networking.networkmanager.enable = true;
}
