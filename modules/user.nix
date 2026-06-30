{config, lib, ...}: {
    imports = [
        ./user/mako.nix
        ./user/yazi.nix
        ./user/sleepMode.nix
        ./user/ghostty.nix
        ./user/zed-idea.nix
        ./user/walker.nix
        ./user/btop.nix
        ./user/zsh.nix
        ./user/packages/utils.nix
        ./user/packages/desktop.nix
        ./user/packages/kdenlive.nix
        ./user/quickshell.nix
        ./user/wob.nix
    ];
}
