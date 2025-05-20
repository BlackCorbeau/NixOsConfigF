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
    texmaker
    libreoffice
    wget
    home-manager
    pkgs.opera

    #git
    pkgs.git
    lazygit
    #terminals
    ghostty

    #fprAGS


    #basePrograms for work
    pkgs.wofi
    pkgs.google-chrome
    pkgs.libsForQt5.kolourpaint
    grimblast
    tree
    slurp
    neofetch
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
    jetbrains.idea-community

    #Utiles
    postman

    # Code
    zed-editor
    nodejs

    #C/C++
    qtcreator

    #java
    gradle
    openjdk
    
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
