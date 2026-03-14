{ config, lib, pkgs, self, ... }:
{
  imports = [ ./hardware-configuration.nix ];
  
  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Host identification
  networking.hostName = "nixos-vm";
  
  # System state version (DO NOT CHANGE)
  system.stateVersion = "25.05";

  # === 以下を追加 ===

  nixpkgs.overlays = [
    (final: prev: {
      zmx = final.callPackage (self + "/hosts/nixos-vm/zmx.nix") { };
    })
  ];

  environment.systemPackages = with pkgs; [
    zmx
  ];
}