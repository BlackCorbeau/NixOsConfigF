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
    libreoffice
    wget
    home-manager
    bat

    #VPN
    openvpn

    #git
    pkgs.git
    lazygit
    #terminals
    ghostty

    #VideoEditor
    kdePackages.kdenlive

    #basePrograms for work
    pkgs.wofi
    pkgs.google-chrome
    tor-browser
    pkgs.libsForQt5.kolourpaint
    grimblast
    tree
    slurp
    fastfetch
    mako
    file
    btop
    nix-index
    unzip
    light
    zip
    brightnessctl
    openssl
    yazi

    swww
    gnumake

    python
    (python3.withPackages (ps: with ps; [ requests bpython ]))
    python311Packages.pip

    #text editor
    helix

    # IDES
    #jetbrains.idea-community

    #Utiles
    postman

    # Code
    zed-editor

    #java
    gradle
    openjdk

    #Kotlin
    kotlin
    android-studio
    
    #DB
    postgresql
    dbgate

    # Bluetooth
    bluez
    bluez-tools

    # Sounds
    pipewire
    pulseaudio
    pamixer
    cava

    # obs-studio
    obs-studio

    #videoManager
    vlc

    #learning
    zoom-us
    obsidian

    #Usb mouting and acsess
    udisks

    #virtualization
    qemu
    kdePackages.partitionmanager
  ];

  fonts.packages = with pkgs; [
    jetbrains-mono
    noto-fonts
    (google-fonts.override{fonts=["Press Start 2P" "Overpass Mono"];})
    noto-fonts-emoji
    noto-fonts-cjk-sans
    twemoji-color-font
    font-awesome
    powerline-fonts
    powerline-symbols
    ubuntu_font_family
    unifont
    nerd-fonts.symbols-only
    corefonts
  ];
}
