{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # Re-export upstream outputs, but keep them overrideable.
      packages = lib.mapAttrs (_: v: lib.mkDefault v) inputs.upstream.packages.${pkgs.system};
      apps = lib.mapAttrs (_: v: lib.mkDefault v) inputs.upstream.apps.${pkgs.system};
      checks = lib.mapAttrs (_: v: lib.mkDefault v) inputs.upstream.checks.${pkgs.system};
      formatter = lib.mkDefault inputs.upstream.formatter.${pkgs.system};
    };
}
