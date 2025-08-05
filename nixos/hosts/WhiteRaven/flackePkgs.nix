{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
  inputs.compose2nix.packages.x86_64-linux.default
  ];
}
