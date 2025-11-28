{config, lib, ...}: {
    imports = [
        ./user/ags.nix
        ./user/mako.nix
        ./user/yazi.nix
        ./user/sleepMode.nix
        ./user/ghostty.nix
        ./user/zed-idea.nix
        ./user/wofi.nix
        ./user/btop.nix
        ./user/zsh.nix
        ./user/packages/tex.nix
        ./user/packages/utils.nix
        ./user/packages/desktop.nix
    ];
}
