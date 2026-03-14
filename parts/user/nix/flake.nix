{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, home-manager, flake-utils }:
    let
      # Generate homeConfigurations for all systems  
      mkHomeConfig = system: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        modules = [ ./home.nix ];
      };
      
      # Create homeConfigurations for all default systems
      allHomeConfigs = builtins.listToAttrs (
        map (system: {
          name = "nixos-${system}";
          value = mkHomeConfig system;
        }) flake-utils.lib.defaultSystems
      );
    in
    flake-utils.lib.eachDefaultSystem (system: 
      let
        pkgs = nixpkgs.legacyPackages.${system};
        homeConfig = mkHomeConfig system;
      in {
        packages.default = homeConfig.activationPackage;
        
        # UX improvement: Enable `nix run .#activate`
        apps.activate = {
          type = "app";
          program = "${homeConfig.activationPackage}/activate";
        };
        
        # Quality assurance
        checks.default = homeConfig.activationPackage;
        formatter = pkgs.nixfmt-rfc-style;
      }) // {
      homeConfigurations = allHomeConfigs // {
        # Backward compatibility: default to x86_64-linux
        nixos = allHomeConfigs."nixos-x86_64-linux";
      };
    };
}