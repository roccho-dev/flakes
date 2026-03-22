{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    pkgs.lib.optionalAttrs (builtins.hasAttr system inputs.amp.packages) {
      packages.amp = inputs.amp.packages.${system}.amp;
      checks.amp = inputs.amp.checks.${system}."amp-help";
    };
}
