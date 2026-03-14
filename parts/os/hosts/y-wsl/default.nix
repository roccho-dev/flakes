{ config, lib, pkgs, ... }:

{
  wsl.enable = true;
  wsl.defaultUser = "nixos";

  system.stateVersion = "25.05"; # Did you read the comment?
}
