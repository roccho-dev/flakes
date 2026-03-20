{ pkgs, ... }:

let
  opencode = import ./package.nix { inherit pkgs; };

  serve = pkgs.writeShellScript "opencode-home-serve" ''
    set -euo pipefail

    : "''${OPENCODE_MIN_UPTIME_SECS:=5}"

    SECONDS=0
    printf '[opencode-home] starting opencode serve (min_uptime=%ss)\n' "$OPENCODE_MIN_UPTIME_SECS" >&2

    if "${opencode}/bin/opencode" \
      serve --hostname "''${OPENCODE_LISTEN_HOST:-0.0.0.0}" \
      --port "''${OPENCODE_PORT:-4096}" \
      --print-logs
    then
      rc=0
    else
      rc=$?
    fi

    elapsed=$SECONDS

    printf '[opencode-home] opencode serve exited rc=%s after %ss\n' "$rc" "$elapsed" >&2

    if [ "$rc" -eq 0 ] && [ "$elapsed" -lt "$OPENCODE_MIN_UPTIME_SECS" ]; then
      printf '[opencode-home] clean exit happened before %ss; treating as failure\n' "$OPENCODE_MIN_UPTIME_SECS" >&2
      exit 70
    fi

    exit "$rc"
  '';
in
{
  systemd.user.services.opencode-home = {
    Unit = {
      Description = "OpenCode server";
      After = [ "default.target" ];
    };

    Service = {
      Type = "simple";
      WorkingDirectory = "/home/nixos";
      ExecStart = "${serve}";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "HOME=/home/nixos"
        "XDG_CONFIG_HOME=/home/nixos/.config"
        "XDG_CACHE_HOME=/home/nixos/.cache"
        "XDG_DATA_HOME=/home/nixos/.local/share"
        "XDG_STATE_HOME=/home/nixos/.local/state"
        "OPENCODE_LISTEN_HOST=0.0.0.0"
        "OPENCODE_PORT=4096"
        "OPENCODE_MIN_UPTIME_SECS=5"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
