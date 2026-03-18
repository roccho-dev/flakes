{ lib, ... }:
{
  # Quick checks:
  #   nix build .#nmo
  #   nix run .#nmo -- --help
  perSystem =
    { pkgs, system, ... }:
    let
      repoRoot = ../..;

      releaseTripletBySystem = {
        x86_64-linux = "x86_64-unknown-linux-gnu";
        aarch64-linux = "aarch64-unknown-linux-gnu";
      };

      releaseHashBySystem = {
        x86_64-linux = "sha256-8kqKOsZ9N+KNWG8UUah0SGsYw1mWihE8HdgAVzND6LM=";
        aarch64-linux = "sha256-tl0GCDNXQC5oSPxXixsgmRnglyL8VYCEL4f82DHmgis=";
      };

      releaseTriplet = releaseTripletBySystem.${system} or null;
      releaseHash = releaseHashBySystem.${system} or null;
    in
    if releaseTriplet == null || releaseHash == null then
      { }
    else
      let
        version = "0.9.1";

        releaseTarball = pkgs.fetchurl {
          url = "https://github.com/knowsys/nemo/releases/download/v${version}/nemo_v${version}_${releaseTriplet}.tar.gz";
          hash = releaseHash;
        };

        commonBuildInputs = [
          pkgs.glibc
          pkgs.openssl
          pkgs.stdenv.cc.cc.lib
          pkgs.zlib
        ];

        mkNemoReleasedBinary =
          {
            pname,
            binName,
            description,
          }:
          pkgs.stdenvNoCC.mkDerivation {
            inherit pname version;
            src = releaseTarball;

            nativeBuildInputs = [
              pkgs.autoPatchelfHook
            ];

            buildInputs = commonBuildInputs;

            strictDeps = true;
            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall

              mkdir -p "$out/bin"

              binPath="./${binName}"
              if [ ! -f "$binPath" ]; then
                releaseDir="./nemo_v${version}_${releaseTriplet}"
                binPath="$releaseDir/${binName}"
              fi

              if [ ! -f "$binPath" ]; then
                echo "error: could not find ${binName} in upstream Nemo release tarball" >&2
                exit 1
              fi

              install -Dm755 "$binPath" "$out/bin/${binName}"

              runHook postInstall
            '';

            meta = {
              inherit description;
              homepage = "https://github.com/knowsys/nemo";
              mainProgram = binName;
              platforms = builtins.attrNames releaseTripletBySystem;
              sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            };
          };

        nmo = mkNemoReleasedBinary {
          pname = "nmo";
          binName = "nmo";
          description = "Upstream Nemo CLI (nmo) repackaged for NixOS with autoPatchelf";
        };

        nemoLanguageServer = mkNemoReleasedBinary {
          pname = "nemo-language-server";
          binName = "nemo-language-server";
          description = "Upstream Nemo language server repackaged for NixOS with autoPatchelf";
        };
      in
      {
        packages = {
          inherit nmo;
          "nemo-language-server" = nemoLanguageServer;
        };

        apps.nmo = {
          type = "app";
          program = "${nmo}/bin/nmo";
        };

        apps."nemo-language-server" = {
          type = "app";
          program = "${nemoLanguageServer}/bin/nemo-language-server";
        };

        checks.nmo-smoke = pkgs.runCommand "nmo-smoke" { } ''
          ${nmo}/bin/nmo --help > "$out"
        '';

        checks.contract-non-regression = pkgs.runCommand "contract-non-regression" {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.diffutils
            pkgs.findutils
            pkgs.gawk
            pkgs.git
            pkgs.gnugrep
            pkgs.gnused
          ];
        } ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"

          export LC_ALL=C
          export NMO="${nmo}/bin/nmo"

          # Flake sources are read-only; copy to a writable dir so we can
          # patch /usr/bin/env shebangs (Nix build sandbox has no /usr/bin/env).
          work="$TMPDIR/repo"
          mkdir -p "$work"
          cp -a "${repoRoot}/." "$work/"
          chmod -R u+w "$work" || true

          if type patchShebangs >/dev/null 2>&1; then
            patchShebangs "$work"
          else
            # Fallback: patch only bash env shebangs.
            while IFS= read -r -d $'\0' f; do
              first_line="$(sed -n '1p' "$f" 2>/dev/null || true)"
              if [[ "$first_line" == '#!/usr/bin/env bash' ]]; then
                sed -i "1s|^#!/usr/bin/env bash$|#!${pkgs.bash}/bin/bash|" "$f"
              fi
            done < <(find "$work" -type f -print0)
          fi

          "$work/test/non_regression/bin/meta_gate.sh"

          mkdir -p "$out"
          echo PASS > "$out/result.txt"
        '';
      };
}
