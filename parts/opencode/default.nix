{ ... }:
{
  imports = [
    ./checks.nix
  ];

  perSystem =
    { pkgs, ... }:
    {
      packages.opencode = import ./package.nix { inherit pkgs; };
    };
}
