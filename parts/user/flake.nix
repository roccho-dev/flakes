{
  description = "User configuration (Home Manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    home-manager,
    flake-utils,
    ...
  }:
    let
      mkHomeConfig = system:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [ ./nix/home.nix ];
        };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        cfg = mkHomeConfig system;
      in
      {
        packages.default = cfg.activationPackage;
      })
    // {
      homeConfigurations.nixos = mkHomeConfig "x86_64-linux";
    };
}
