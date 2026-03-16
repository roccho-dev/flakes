{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      zig = inputs.upstream.packages.${pkgs.system}.zig-tooling;

      # Pinned upstream sources (match recovered artifacts).
      zigQuickjsNgSrc = pkgs.fetchFromGitHub {
        owner = "mitchellh";
        repo = "zig-quickjs-ng";
        rev = "eb1d44ce43fd64f8403c1a94fad242ebae04d1fb";
        hash = "sha256-MnfTfcfTrTo5YxZtdb5enITyS8KliAH1giDZXOT2XtQ=";
      };

       # Host-facing URL/hash (for build.zig.zon consumers).
       zigQuickjsNgUrl = "https://github.com/mitchellh/zig-quickjs-ng/archive/eb1d44ce43fd64f8403c1a94fad242ebae04d1fb.tar.gz";
       zigQuickjsNgZigHash = "quickjs_ng-0.0.0-0cZnA8XHAwCc95T1GAebWrw-SGEwp1Y0fUAmilP8xGuS";

      # Dependency URL/hash as declared by zig-quickjs-ng's build.zig.zon.
      quickjsUrl = "https://github.com/quickjs-ng/quickjs/archive/85640f81e04bc93940acc2756c792c66076dd768.tar.gz";
      quickjsZigHash = "N-V-__8AAIZ_PAA7y10jIaLigzkK4qd5-jfKEoTOOfHCsIGM";

      quickjsTarball = pkgs.fetchurl {
        url = quickjsUrl;
        hash = "sha256-QdTkxlNQ1u5oJw0KdBZJK+6du6G6Wkj/Ot0Q20a40PU=";
      };

       zigQuickjsNgTarball = pkgs.fetchurl {
         url = zigQuickjsNgUrl;
         hash = "sha256-IWBlQDj32F92NCf9pBQj2r3FxVBEXFLtlEX/3YhveUU=";
       };

      # Optional: unpacked quickjs-ng source tree (handy for inspection).
      quickjsNgSrc = pkgs.fetchFromGitHub {
        owner = "quickjs-ng";
        repo = "quickjs";
        rev = "85640f81e04bc93940acc2756c792c66076dd768";
        hash = "sha256-An5zcL2wu6Qzv2AC+++zPP58XQp5A+zcMFi1H38oUGY=";
      };

      pkgdir = pkgs.stdenv.mkDerivation {
        pname = "zig-quickjs-ng-pkgdir";
        version = "0.0.0";

        dontUnpack = true;
        dontFixup = true;
        nativeBuildInputs = [ zig ];

        buildPhase = ''
          runHook preBuild

          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
          export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"

          got_hash="$(zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "${quickjsTarball}")"
          if [ "$got_hash" != "${quickjsZigHash}" ]; then
            echo "zig fetch hash mismatch" >&2
            echo "  got:      $got_hash" >&2
            echo "  expected: ${quickjsZigHash}" >&2
            exit 1
          fi

          # zig build --system <pkgdir> expects <pkgdir>/<hash>/... (not p/<hash>).
          mkdir -p "$out"
          cp -a "$ZIG_GLOBAL_CACHE_DIR/p/$got_hash" "$out/$got_hash"
          printf '%s\n' "$got_hash" > "$out/quickjs.hash"

          runHook postBuild
        '';

        installPhase = "true";

        meta = {
          description = "Zig --system pkgdir for quickjs-ng tarball";
          platforms = pkgs.lib.platforms.all;
        };
      };

      systemPkgdir = pkgs.stdenv.mkDerivation {
        pname = "zig-quickjs-ng-system-pkgdir";
        version = "0.0.0";

        dontUnpack = true;
        dontFixup = true;
        nativeBuildInputs = [ zig ];

        buildPhase = ''
          runHook preBuild

           export HOME="$TMPDIR/home"
           mkdir -p "$HOME"
           export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
           export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"

           mkdir -p "$out"

           got_hash_zig_quickjs_ng="$(zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "${zigQuickjsNgTarball}")"
           if [ "$got_hash_zig_quickjs_ng" != "${zigQuickjsNgZigHash}" ]; then
             echo "zig fetch hash mismatch (zig-quickjs-ng)" >&2
             echo "  got:      $got_hash_zig_quickjs_ng" >&2
             echo "  expected: ${zigQuickjsNgZigHash}" >&2
             exit 1
           fi
           cp -a "$ZIG_GLOBAL_CACHE_DIR/p/$got_hash_zig_quickjs_ng" "$out/$got_hash_zig_quickjs_ng"
           printf '%s\n' "$got_hash_zig_quickjs_ng" > "$out/zig-quickjs-ng.hash"

           got_hash_quickjs="$(zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "${quickjsTarball}")"
           if [ "$got_hash_quickjs" != "${quickjsZigHash}" ]; then
             echo "zig fetch hash mismatch (quickjs)" >&2
             echo "  got:      $got_hash_quickjs" >&2
             echo "  expected: ${quickjsZigHash}" >&2
             exit 1
           fi
           cp -a "$ZIG_GLOBAL_CACHE_DIR/p/$got_hash_quickjs" "$out/$got_hash_quickjs"
           printf '%s\n' "$got_hash_quickjs" > "$out/quickjs.hash"

          runHook postBuild
        '';

        installPhase = "true";

        meta = {
          description = "Zig --system pkgdir for consuming zig-quickjs-ng";
          platforms = pkgs.lib.platforms.all;
        };
      };

      pkg = pkgs.stdenv.mkDerivation {
        pname = "zig-quickjs-ng";
        version = "0.0.0+eb1d44ce";

        src = zigQuickjsNgSrc;

        nativeBuildInputs = [ zig ];

        buildPhase = ''
          runHook preBuild

          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
          export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"

          zig build --system "${pkgdir}" -Doptimize=ReleaseSafe --prefix "$out"

          runHook postBuild
        '';

        installPhase = "true";

        meta = {
          description = "Zig bindings for quickjs-ng (static lib + header)";
          homepage = "https://github.com/mitchellh/zig-quickjs-ng";
          license = pkgs.lib.licenses.mit;
          platforms = pkgs.lib.platforms.all;
        };
      };

      zonUnchanged = pkgs.runCommand "zig-quickjs-ng-zon-unchanged" { } ''
        set -euo pipefail

        cd "${zigQuickjsNgSrc}"
        # Ensure we did not switch to .path contract.
        if grep -Eq '^[[:space:]]*\.path[[:space:]]*=' build.zig.zon; then
          echo "build.zig.zon contains .path (unexpected)" >&2
          exit 1
        fi
        grep -Fq "${quickjsUrl}" build.zig.zon
        grep -Fq "${quickjsZigHash}" build.zig.zon

        mkdir -p "$out"
        echo ok > "$out/result"
      '';

      depsHashMatch = pkgs.runCommand "zig-quickjs-ng-deps-hash-match" { nativeBuildInputs = [ zig ]; } ''
        set -euo pipefail

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"

        got_hash="$(zig fetch --global-cache-dir "$ZIG_GLOBAL_CACHE_DIR" "${quickjsTarball}")"
        if [ "$got_hash" != "${quickjsZigHash}" ]; then
          echo "zig fetch hash mismatch" >&2
          echo "  got:      $got_hash" >&2
          echo "  expected: ${quickjsZigHash}" >&2
          exit 1
        fi

        mkdir -p "$out"
        echo "$got_hash" > "$out/hash"
      '';

      offlineTest = pkgs.runCommand "zig-quickjs-ng-offline-test" { nativeBuildInputs = [ zig ]; } ''
        set -euo pipefail

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
        export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"

        cd "${zigQuickjsNgSrc}"
        zig build test --system "${pkgdir}" -Doptimize=ReleaseSafe

        mkdir -p "$out"
        echo ok > "$out/result"
      '';

      hostExampleSrc = ../../examples/zig-quickjs-ng-host;

      hostExampleZonUnchanged = pkgs.runCommand "zig-quickjs-ng-host-example-zon-unchanged" { } ''
         set -euo pipefail

         cd "${hostExampleSrc}"
         # Ensure we did not switch to .path contract.
         if grep -Eq '^[[:space:]]*\.path[[:space:]]*=' build.zig.zon; then
           echo "build.zig.zon contains .path (unexpected)" >&2
           exit 1
         fi
         grep -Fq "${zigQuickjsNgUrl}" build.zig.zon
         grep -Fq "${zigQuickjsNgZigHash}" build.zig.zon

         mkdir -p "$out"
         echo ok > "$out/result"
       '';

      hostExample = pkgs.stdenv.mkDerivation {
         pname = "zig-quickjs-ng-host-example";
         version = "0.0.0";

         src = hostExampleSrc;
         nativeBuildInputs = [ zig ];

         buildPhase = ''
           runHook preBuild

           export HOME="$TMPDIR/home"
           mkdir -p "$HOME"
           export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
           export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"

           zig build --system "${systemPkgdir}" -Doptimize=ReleaseSafe --prefix "$out"

           runHook postBuild
         '';

         installPhase = "true";

         meta = {
           description = "Example Zig host embedding quickjs-ng";
           platforms = pkgs.lib.platforms.all;
         };
       };

      hostExampleRun = pkgs.runCommand "zig-quickjs-ng-host-example-run" { } ''
         set -euo pipefail

         "${hostExample}/bin/qjs-host-example"

         mkdir -p "$out"
         echo ok > "$out/result"
       '';

      hostSmoke = pkgs.runCommand "zig-quickjs-ng-host-smoke" { nativeBuildInputs = [ zig ]; } ''
        set -euo pipefail

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
        export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"

        cd "$TMPDIR"

        cat > main.zig <<'EOF'
        const c = @cImport({
            @cInclude("quickjs.h");
        });

        pub fn main() void {
            const rt = c.JS_NewRuntime();
            if (rt == null) @panic("JS_NewRuntime failed");
            c.JS_FreeRuntime(rt);
        }
        EOF

        zig build-exe main.zig \
          -Doptimize=ReleaseSafe \
          -I "${pkg}/include" \
          -L "${pkg}/lib" \
          -lquickjs-ng \
          -lc -lm -ldl -lpthread \
          -femit-bin=./host-smoke

        mkdir -p "$out"
        ./host-smoke
        echo ok > "$out/result"
      '';
    in
    {
      packages.zig-quickjs-ng-src = zigQuickjsNgSrc;
      packages.quickjs-ng-src = quickjsNgSrc;
      packages.quickjs-ng-tarball = quickjsTarball;
      packages.zig-quickjs-ng-tarball = zigQuickjsNgTarball;
      packages.zig-quickjs-ng-pkgdir = pkgdir;
      packages.zig-quickjs-ng-system-pkgdir = systemPkgdir;
      packages.zig-quickjs-ng = pkg;
      packages.zig-quickjs-ng-host-example = hostExample;
      packages.default = pkg;

      checks.zig-quickjs-ng = pkg;
      checks.zig-quickjs-ng-zon-unchanged = zonUnchanged;
      checks.zig-quickjs-ng-deps-hash-match = depsHashMatch;
      checks.zig-quickjs-ng-offline-build = pkg;
      checks.zig-quickjs-ng-offline-test = offlineTest;
      checks.zig-quickjs-ng-host-smoke = hostSmoke;
      checks.zig-quickjs-ng-system-pkgdir = systemPkgdir;
      checks.zig-quickjs-ng-host-example-zon-unchanged = hostExampleZonUnchanged;
      checks.zig-quickjs-ng-host-example-offline-build = hostExample;
      checks.zig-quickjs-ng-host-example-run = hostExampleRun;

      devShells.zig-quickjs-ng = pkgs.mkShell {
        packages = [ zig ];
      };
    };
}
