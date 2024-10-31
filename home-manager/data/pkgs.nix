{config, pkgs, ...}: {
    imports = [
        ./hyprland.nix
        ./waybar.nix
        ./style.nix
        ./git.nix
        ./mako.nix
        ./yazi.nix
    ];
}
