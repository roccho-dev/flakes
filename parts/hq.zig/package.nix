{ lib, ... }:
let
  src = lib.cleanSource ./.;
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.hq-zig-src = pkgs.stdenvNoCC.mkDerivation {
        pname = "hq-zig-src";
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

      checks.hq-zig-part-layout = pkgs.runCommand "hq-zig-part-layout" { } ''
        test -f ${./build.zig}
        test -f ${./README.md}
        test -f ${../chromedevtoolprotocol.zig/src/root.zig}

        mkdir -p "$out"
        printf 'ok\n' > "$out/result"
      '';
    };
}
