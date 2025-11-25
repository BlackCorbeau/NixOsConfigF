{config, pkgs, ...}: {
    imports = [
        ./user/ags.nix
        ./user/mako.nix
        ./user/yazi.nix
        ./user/sleepMode.nix
        ./user/ghostty.nix
        ./user/home-aps.nix
        ./user/zed-idea.nix
        ./user/wofi.nix
        ./user/tex.nix
        ./user/btop.nix
    ];
}
