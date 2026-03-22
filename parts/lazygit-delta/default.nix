{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      mkLazygitDelta = import ./module.nix;
      mod = mkLazygitDelta { inherit pkgs; };

      mkChecks = import ./checks.nix;
    in
    {
      # Entrypoint policy: expose as a package only (no apps/run entrypoint).
      packages.lazygit = mod.package;

      checks = mkChecks {
        inherit pkgs;
        package = mod.package;
        cfgFile = mod.cfgFile;
      };
    };
}
