{ config, pkgs, ... }:

{
  services.zapret-discord-youtube = {
    enable = true;
    config = "general(ALT)";   # или любой другой

    gameFilter = "null";       # "all", "tcp", "udp" или "null"

    listGeneral = [ "example.com" "test.org" "mysite.net" ];
    listExclude = [ "ubisoft.com" "origin.com" ];

    ipsetAll = [ "192.168.1.0/24" "10.0.0.1" ];
    ipsetExclude = [ "203.0.113.0/24" ];
  };
}
