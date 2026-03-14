{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      zmx = final.callPackage ./package.nix { };
    })
  ];

  environment.systemPackages = [ pkgs.zmx ];
}
