{ config, pkgs, ... }:

{
  # Включение ZeroTierOne
  services.zerotierone = {
    enable = true;
    joinNetworks = [ "NETWORK_ID" ];  # Замените на ID вашей сети ZeroTier
  };

  # Или, если не хотите автоматически подключаться к сети, просто включите сервис:
  # services.zerotierone.enable = true;

  # Открытие порта для ZeroTier (опционально)
  networking.firewall.allowedUDPPorts = [ 9993 ];

  # Установка пакета
  environment.systemPackages = [ pkgs.zerotierone ];
}
