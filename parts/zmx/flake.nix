{
  description = "zmx: pinned upstream tarball";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        if system == "x86_64-linux" then
          rec {
            zmx = pkgs.callPackage ./package.nix { };
            default = zmx;
          }
        else
          { }
      );

      overlays.default = final: prev: {
        zmx = final.callPackage ./package.nix { };
      };

      nixosModules.default = import ./nixos.nix;
    };
}
