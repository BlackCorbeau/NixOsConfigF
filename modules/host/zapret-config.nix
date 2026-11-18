{ config, pkgs, lib, ... }:
let
  iptables = "${pkgs.iptables}/bin/iptables";

  # Bypass zapret NFQUEUE processing for VPN tunnel interfaces so that
  # Clash Verge (TUN mode) and zapret can work together without interfering
  # with each other's traffic.
  zapretVpnBypass = pkgs.writeShellScript "zapret-vpn-bypass" ''
    set -euo pipefail

    add_bypass() {
      local table="$1" chain="$2" dir_flag="$3" iface="$4"
      # Insert RETURN before zapret's NFQUEUE rules if not already present.
      if ! ${iptables} -w -t "$table" -C "$chain" "$dir_flag" "$iface" -j RETURN 2>/dev/null; then
        ${iptables} -w -t "$table" -I "$chain" 1 "$dir_flag" "$iface" -j RETURN
      fi
    }

    for iface in Mihomo Meta tun0 tun1 tun2 utun0 utun1 clash0; do
      # Outgoing packets routed into the VPN tunnel / replies from it.
      add_bypass mangle POSTROUTING -o "$iface"
      add_bypass mangle OUTPUT      -o "$iface"
      add_bypass mangle PREROUTING  -i "$iface"
      add_bypass mangle INPUT       -i "$iface"
    done

    # Also support common TUN name prefix used by some cores.
    for iface in tun+ utun+; do
      if ! ${iptables} -w -t mangle -C POSTROUTING -o "$iface" -j RETURN 2>/dev/null; then
        ${iptables} -w -t mangle -I POSTROUTING 1 -o "$iface" -j RETURN
      fi
      if ! ${iptables} -w -t mangle -C OUTPUT -o "$iface" -j RETURN 2>/dev/null; then
        ${iptables} -w -t mangle -I OUTPUT 1 -o "$iface" -j RETURN
      fi
      if ! ${iptables} -w -t mangle -C PREROUTING -i "$iface" -j RETURN 2>/dev/null; then
        ${iptables} -w -t mangle -I PREROUTING 1 -i "$iface" -j RETURN
      fi
      if ! ${iptables} -w -t mangle -C INPUT -i "$iface" -j RETURN 2>/dev/null; then
        ${iptables} -w -t mangle -I INPUT 1 -i "$iface" -j RETURN
      fi
    done
  '';
in
{
  # VPN TUN interfaces (e.g. Clash Verge) require loose reverse path filtering.
  networking.firewall.checkReversePath = "loose";

  services.zapret-discord-youtube = {
    enable = true;
    configName = "general(ALT)"; # Или любой конфиг из папки configs (general, general(ALT), general (SIMPLE FAKE) и т.д.)

    # Game Filter: "null" (отключен), "all" (TCP+UDP), "tcp" (только TCP), "udp" (только UDP)
    gameFilter = "null"; # или "all", "tcp", "udp"

    # Добавляем кастомные домены в list-general-user.txt
    listGeneral = [ "example.com" "test.org" "mysite.net" ];

    # Добавляем домены в list-exclude-user.txt (исключения)
    listExclude = [ "ubisoft.com" "origin.com" ];

    # Добавляем IP адреса в ipset-all.txt
    ipsetAll = [ "192.168.1.0/24" "10.0.0.1" ];

    # Добавляем IP адреса в ipset-exclude-user.txt (исключения)
    ipsetExclude = [ "203.0.113.0/24" ];
  };

  # Make zapret compatible with Clash Verge TUN mode by excluding VPN tunnel
  # interfaces from nfqws processing after zapret applies its firewall rules.
  systemd.services.zapret-discord-youtube.serviceConfig.ExecStartPost =
    lib.mkAfter [ zapretVpnBypass ];
}
