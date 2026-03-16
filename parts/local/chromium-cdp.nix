{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      chromiumPkg = pkgs.chromium;

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

        exec ${pkgs.curl}/bin/curl -sS "http://$addr:$port/json/version" | ${pkgs.jq}/bin/jq -r .webSocketDebuggerUrl
      '';
    in
    {
      packages.hq-chromium = chromiumPkg;
      packages.chromium-cdp = chromiumCdp;
      packages.chromium-cdp-wsurl = chromiumCdpWsUrl;

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
