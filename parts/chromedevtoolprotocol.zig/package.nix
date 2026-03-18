{ lib, ... }:
let
  src = lib.cleanSource ./.;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.chromedevtoolprotocol-zig-src = pkgs.stdenvNoCC.mkDerivation {
        pname = "chromedevtoolprotocol-zig-src";
        version = "0.0.0";
        inherit src;
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          mkdir -p "$out"
          cp -R "$src"/. "$out"/
          chmod -R u+w "$out"
        '';
      };

      checks.chromedevtoolprotocol-zig-part-layout = pkgs.runCommand "chromedevtoolprotocol-zig-part-layout" { } ''
        test -f ${./build.zig}
        test -f ${./src/root.zig}
        test -f ${./README.md}

        mkdir -p "$out"
        printf 'ok\n' > "$out/result"
      '';
    };
}
