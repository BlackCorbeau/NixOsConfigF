{ pkgs, inputs, ... }: {

  environment.systemPackages = with pkgs; [
    file
    tree
    wget
    git
    (btop.override { cudaSupport = true; })
    unzip
    yazi
    zip
    lazygit
    httpie
    ncdu
    tldr
    helix
    bluetui
    fastfetch
    thunderbird
  ];

  fonts = {
    enableDefaultPackages = false;
    packages = with pkgs; [
      jetbrains-mono          # Best mono font
      noto-fonts-cjk-sans     # Japanese
      powerline-symbols       # Console decoration
      unifont                 # Other
      (pkgs.runCommand "liberation-serif-only" {} ''
        mkdir -p "$out/share/fonts/truetype"
      
        find ${pkgs.liberation_ttf} \
          -type f \
          -name 'LiberationSerif-*.ttf' \
          -exec install -m644 {} "$out/share/fonts/truetype/" \;
      
        mkdir -p "$out/share"
        cp -r ${pkgs.liberation_ttf}/share/doc "$out/share/"
      '')                    #"Times New Roman" for office
      (pkgs.google-fonts.override { fonts = [ "Gabriela" ]; })
    ];
  };
  fonts.fontconfig.enable = true;
}
