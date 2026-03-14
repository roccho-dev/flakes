{ config, lib, pkgs, self, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base/vm.nix
    ../../../zmx/nixos.nix
  ];

  networking.hostName = "nixos-vm";

  # System state version (DO NOT CHANGE)
  system.stateVersion = "25.05";

}
