{ pkgs }:
let
  opencode = import ./lib.nix;
in
pkgs.writeShellScriptBin "opencode" ''
  set -euo pipefail

  export OPENCODE_CONFIG="${opencode.defaultEnv.OPENCODE_CONFIG}"

  : "''${OPENCODE_DISABLE_LSP_DOWNLOAD:=${opencode.defaultEnv.OPENCODE_DISABLE_LSP_DOWNLOAD}}"
  : "''${OPENCODE_DISABLE_AUTOUPDATE:=${opencode.defaultEnv.OPENCODE_DISABLE_AUTOUPDATE}}"
  export OPENCODE_DISABLE_LSP_DOWNLOAD OPENCODE_DISABLE_AUTOUPDATE

  exec "${pkgs.opencode}/bin/opencode" "$@"
''
