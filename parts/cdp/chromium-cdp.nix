{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      chromiumPkg = pkgs.chromium;
      zigForCdp = config.packages."zig-0_16-tooling" or pkgs.zig;

      cdpBridge = pkgs.stdenv.mkDerivation {
        pname = "cdp-bridge";
        version = "0.1.0";
        src = ./cdp-bridge.zig;
        dontUnpack = true;
        nativeBuildInputs = [ zigForCdp ];
        buildPhase = ''
          runHook preBuild
          export HOME="$TMPDIR/home"
          export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
          mkdir -p "$HOME" "$ZIG_GLOBAL_CACHE_DIR"
          mkdir -p "$out/bin"
          zig build-exe -O ReleaseSafe -fstrip -femit-bin="$out/bin/cdp-bridge" "$src"
          runHook postBuild
        '';
        installPhase = "true";
      };

      chromiumCdp = pkgs.writeShellScriptBin "chromium-cdp" ''
        set -euo pipefail

        port="''${HQ_CHROME_PORT:-9222}"
        addr="''${HQ_CHROME_ADDR:-127.0.0.1}"
        profile_dir="''${HQ_CHROME_PROFILE_DIR:-$HOME/.secret/hq/chromium-cdp-profile}"

        mkdir -p "$profile_dir" 2>/dev/null || true
        chmod 700 "$profile_dir" 2>/dev/null || true

        extra=()
        if [ "''${HQ_CHROME_HEADLESS:-0}" = "1" ]; then
          extra+=(--headless=new --disable-gpu)
        fi
        if [ "''${HQ_CHROME_NO_SANDBOX:-0}" = "1" ]; then
          extra+=(--no-sandbox --disable-setuid-sandbox)
        fi

        exec ${chromiumPkg}/bin/chromium \
          --remote-debugging-address="$addr" \
          --remote-debugging-port="$port" \
          --user-data-dir="$profile_dir" \
          --no-first-run \
          --no-default-browser-check \
          --disable-dev-shm-usage \
          "''${extra[@]}" \
          "$@"
      '';

      chromiumCdpWsUrl = pkgs.writeShellScriptBin "chromium-cdp-wsurl" ''
        set -euo pipefail

        port="''${HQ_CHROME_PORT:-9222}"
        addr="''${HQ_CHROME_ADDR:-127.0.0.1}"

        exec ${cdpBridge}/bin/cdp-bridge wsurl --addr "$addr" --port "$port"
      '';

      chromiumCdpTools = pkgs.symlinkJoin {
        name = "chromium-cdp-tools";
        paths = [
          chromiumPkg
          chromiumCdp
          chromiumCdpWsUrl
          cdpBridge
          (pkgs.lib.getBin pkgs.quickjs-ng)
        ];
      };
    in
    {
      packages.hq-chromium = chromiumPkg;
      packages.chromium-cdp = chromiumCdp;
      packages.chromium-cdp-wsurl = chromiumCdpWsUrl;
      packages.cdp-bridge = cdpBridge;
      packages.chromium-cdp-tools = chromiumCdpTools;

      apps.chromium-cdp = {
        type = "app";
        program = "${chromiumCdp}/bin/chromium-cdp";
      };
      apps.chromium-cdp-wsurl = {
        type = "app";
        program = "${chromiumCdpWsUrl}/bin/chromium-cdp-wsurl";
      };
    };
}
