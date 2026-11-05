{config, lib, ...}: {
    imports = [
        ./user/yazi.nix
        ./user/sleepMode.nix
        ./user/ghostty.nix
        ./user/qt.nix
        ./user/helix.nix
        ./user/stylix.nix
        #./user/zed-idea.nix
        ./user/walker.nix
        ./user/btop.nix
        ./user/zsh.nix
        ./user/packages/utils.nix
        ./user/packages/desktop.nix
        ./user/quickshell.nix
        ./user/secrets.nix
    ];
}
