{ pkgs, ... }: {
  imports = [
    ../../modules/user/packages/coding.nix
    ./modules/lucid.nix
  ];
  programs.hyprlock.enable = true;
  home.packages = with pkgs; [
    (vivaldi.override {
      proprietaryCodecs = true;
      enableWidevine = true;
    })
  ];
}
