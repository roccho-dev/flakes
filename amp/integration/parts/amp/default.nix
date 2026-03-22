{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      ampPkg = inputs.amp.packages.${system}.amp;
    in
    {
      packages.amp = ampPkg;
      packages.default = ampPkg;
    };
}
