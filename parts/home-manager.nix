{ inputs, ... }:
{
  flake.homeConfigurations.nixos = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    modules = [ ./user/home.nix ];
  };
}
