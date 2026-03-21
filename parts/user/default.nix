{ lib, ... }:
let
  dir = builtins.readDir ./.;
  names = builtins.attrNames dir;

  nixFiles = builtins.filter (
    name:
    dir.${name} == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" && name != "flake.nix" && name != "home.nix"
  ) names;

  sorted = builtins.sort builtins.lessThan nixFiles;
in
{
  imports = map (name: ./. + "/${name}") sorted;
}
