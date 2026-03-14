{
  description = "NixOS system configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    sops-nix.url = "github:Mic92/sops-nix";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    sops-nix,
    nixos-wsl,
  }:
    let
      system = "x86_64-linux";

      commonModules = [
        ./modules/common.nix
        ./modules/secrets.nix
        sops-nix.nixosModules.sops
        (
          { lib, ... }:
          {
            _module.args.self = lib.mkDefault self;
          }
        )
      ];
    in
    {
      nixosConfigurations = {
        nixos-vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./hosts/nixos-vm/default.nix ] ++ commonModules;
        };

        rent = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/rent/default.nix
            nixos-wsl.nixosModules.wsl
          ] ++ commonModules;
        };
      };
    };
}
