{
  description = "Self-contained flake that exposes the amp package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        lib.genAttrs supportedSystems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          amp = pkgs.callPackage ./packages/amp { };
        in
        {
          inherit amp;
          default = amp;
        }
      );

      apps = forAllSystems (
        pkgs:
        let
          amp = pkgs.callPackage ./packages/amp { };
        in
        {
          amp = {
            type = "app";
            program = "${amp}/bin/amp";
          };
          default = {
            type = "app";
            program = "${amp}/bin/amp";
          };
        }
      );
    };
}
