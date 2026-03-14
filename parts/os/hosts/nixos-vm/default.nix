{ config, lib, pkgs, self, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base/vm.nix
  ];

  networking.hostName = "nixos-vm";

  # System state version (DO NOT CHANGE)
  system.stateVersion = "25.05";

  nixpkgs.overlays = [
    (final: prev: {
      zmx = final.callPackage (self + "/hosts/nixos-vm/zmx.nix") { };
    })
  ];

  environment.systemPackages = with pkgs; [
    zmx
  ];
}
