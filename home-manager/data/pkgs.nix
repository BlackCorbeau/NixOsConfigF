{config, pkgs, ...}: {
    imports = [
        ./hyprland.nix
        ./waybar.nix
        ./style.nix
        ./git.nix
        ./mako.nix
        ./yazi.nix
        ./sleepMode.nix
        ./kitty.nix
        ./home-aps.nix
    ];
}
