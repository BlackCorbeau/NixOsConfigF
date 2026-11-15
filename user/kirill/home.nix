{ pkgs, ... }: {
  imports = [
    ../../modules/user/packages/coding.nix
    ./modules/noctalia.nix
  ];
  # Locking is handled by the Noctalia lockscreen now.
  programs.hyprlock.enable = false;
  home.packages = with pkgs; [
    (vivaldi.override {
      proprietaryCodecs = true;
      enableWidevine = true;
    })
  ];
}
