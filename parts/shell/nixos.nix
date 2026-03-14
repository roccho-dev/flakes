{ pkgs, ... }:

{
  environment.systemPackages = import ./packages.nix { inherit pkgs; };
}
