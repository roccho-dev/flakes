{ pkgs, ... }:

let
  opencode = import ./package.nix { inherit pkgs; };

  serve = pkgs.writeShellScript "opencode-home-serve" ''
    set -euo pipefail

    exec "${opencode}/bin/opencode" \
      serve --hostname "''${OPENCODE_LISTEN_HOST:-0.0.0.0}" \
      --port "''${OPENCODE_PORT:-4096}" \
      --print-logs
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
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
