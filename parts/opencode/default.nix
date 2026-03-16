{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.opencode = lib.mkDefault inputs.upstream.packages.${pkgs.system}.editor-tools;
    };
}
