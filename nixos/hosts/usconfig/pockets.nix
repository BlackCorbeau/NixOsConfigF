{ pkgs, ... }:

#let
#  thingsboard = import ./pockets/thingsboard.nix { inherit pkgs; };
#in
{
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = ["python-2.7.18.8" "electron-25.9.0" "freeimage-unstable-2021-11-01" "obsidian-1.5.12"];
  };

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    home-manager
    pkgs.opera
    pkgs.git
    pkgs.telegram-desktop
    pkgs.vpnc
    pkgs.alacritty
    pkgs.wofi
    pkgs.google-chrome
    pkgs.yazi
    nerdfonts
    pkgs.waybar
    grimblast
    tree
    slurp
    brightnessctl
    neofetch
    mako
    file
    btop
    nix-index
    unzip
    scrot
    ffmpeg
    light
    zram-generator
    zip
    ntfs3g
    yt-dlp
    brightnessctl
    openssl
    httpie
    ncdu
    hexyl
    jq
    tldr
    bat
    xdg-utils
    helix
    playerctl
    duf
    v2raya

    swww
    gnumake

    python
    (python3.withPackages (ps: with ps; [ requests bpython ]))
    python311Packages.pip

    # IDES
    jetbrains.idea-community

    # Languages
    vscode
    nodejs
    gcc
    cmake
    jdk
    maven

    # Bluetooth
    bluez
    bluez-tools

    # Sounds
    pipewire
    pulseaudio
    pamixer

    # obs-studio
    obs-studio

    #videoManager
    vlc

    #learning
    obsidian
  ];# ++ [thingsboard];

  fonts.packages = with pkgs; [
    jetbrains-mono
    noto-fonts
    noto-fonts-emoji
    twemoji-color-font
    font-awesome
    powerline-fonts
    powerline-symbols
    ubuntu_font_family
    unifont
    (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
  ];
}
