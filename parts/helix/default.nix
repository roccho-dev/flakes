{ ... }:
{
  imports = [
    ./contract.nix
    ./gen.nix
    ./checks.nix
  ];

  perSystem =
    { pkgs, config, ... }:
    {
      packages.hx = pkgs.writeShellScriptBin "hx" ''
        set -euo pipefail

        export TMPDIR=''${TMPDIR:-/tmp}

        export HOME="$TMPDIR/helix-home"
        export XDG_CONFIG_HOME="$HOME/.config"
        export XDG_CACHE_HOME="$HOME/.cache"
        export XDG_STATE_HOME="$HOME/.local/state"

        "${pkgs.coreutils}/bin/mkdir" -p "$XDG_CONFIG_HOME/helix" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

        "${pkgs.coreutils}/bin/rm" -f "$XDG_CONFIG_HOME/helix/languages.toml"
        "${pkgs.coreutils}/bin/ln" -s "${config.helix.languagesToml}" "$XDG_CONFIG_HOME/helix/languages.toml"

        exec "${pkgs.helix}/bin/hx" "$@"
      '';
    };
}
