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

    #git
    pkgs.git
    lazygit
    #terminals
    kitty
    alacritty

    #fprAGS


    #basePrograms for work
    pkgs.wofi
    pkgs.google-chrome
    pkgs.libsForQt5.kolourpaint
    pkgs.waybar
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

    # Code
    vscode
    nodejs

    #C/C++
    gcc
    gdb
    cmake
    qtcreator

    #java
    openjfx
    openjdk
    maven

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
