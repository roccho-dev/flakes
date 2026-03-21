{ lib, ... }:
{
  # TODO: Hoist Zig toolchain packaging into `parts/languages/zig.nix` so it can
  # be built independently and consumed from `parts/cdp` as a normal dependency.
  perSystem =
    { pkgs, system, ... }:
    let
      zig016Version = "0.16.0-dev.2915+065c6e794";

      releaseBySystem = {
        x86_64-linux = {
          url = "https://ziglang.org/builds/zig-x86_64-linux-0.16.0-dev.2915+065c6e794.tar.xz";
          sha256 = "ecdbcaf213e33f4117bc75c1b885a7e043450c907627d8b2a35c4e60eb07d0ad";
        };
        aarch64-linux = {
          url = "https://ziglang.org/builds/zig-aarch64-linux-0.16.0-dev.2915+065c6e794.tar.xz";
          sha256 = "d4bc35bb844f27bf59e37c6fcea1878c4753a3a236b497515de55f9f60da8ffa";
        };
      };

      zig016 =
        if builtins.hasAttr system releaseBySystem then
          pkgs.stdenvNoCC.mkDerivation {
            pname = "zig";
            version = zig016Version;

            src = pkgs.fetchurl {
              inherit (releaseBySystem.${system}) url sha256;
            };

            dontUnpack = true;
            dontConfigure = true;
            dontBuild = true;

            nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper pkgs.xz ];
            buildInputs = [ pkgs.stdenv.cc.cc.lib ];

            installPhase = ''
              runHook preInstall
              mkdir -p "$out/bin" "$out/lib/zig-dist"
              tar -xf "$src" --strip-components=1 -C "$out/lib/zig-dist"
              makeWrapper "$out/lib/zig-dist/zig" "$out/bin/zig"
              chmod -R u+w "$out"
              runHook postInstall
            '';

            meta = with lib; {
              description = "Zig ${zig016Version} binary release from ziglang.org";
              homepage = "https://ziglang.org/download/";
              mainProgram = "zig";
              platforms = builtins.attrNames releaseBySystem;
              sourceProvenance = [ sourceTypes.binaryNativeCode ];
            };
          }
        else
          null;

      zig016Tooling =
        if zig016 == null then
          null
        else
          pkgs.symlinkJoin {
            name = "zig-0_16-tooling";
            paths = [ zig016 ];
          };
    in
    {
      packages = lib.optionalAttrs (zig016 != null) {
        zig-0_16 = zig016;
        zig-0_16-tooling = zig016Tooling;
      };

      checks = lib.optionalAttrs (zig016Tooling != null) {
        zig-0_16-smoke = pkgs.runCommand "zig-0_16-smoke" {
          nativeBuildInputs = [ zig016Tooling ];
        } ''
          set -euo pipefail

          zig version | grep '^0\.16\.' >/dev/null
          zig fmt --help >/dev/null

          touch "$out"
        '';
      };
    };
}
