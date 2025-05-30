{config, pkgs, ...}: {
    imports = [
        ./hyprland.nix
        ./ags.nix
        ./style.nix
        ./git.nix
        ./mako.nix
        ./yazi.nix
        ./sleepMode.nix
        ./ghostty.nix
        ./home-aps.nix
        ./zed-idea.nix
        ./wofi.nix 
    ];
}
