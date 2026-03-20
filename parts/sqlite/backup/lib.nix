{ lib, pkgs }:

let
  captureBackupApi = import ./capture-backup-api.nix { inherit pkgs; };
  captureVacuumInto = import ./capture-vacuum-into.nix { inherit pkgs; };
  validateQuickCheck = import ./validate-quick-check.nix { inherit pkgs; };
  validateIntegrity = import ./validate-integrity.nix { inherit pkgs; };
  storeLocal = import ./store-local.nix { };
  retention = import ./retention.nix { };

  captureSnippet = method:
    if method == "backup-api" then
      captureBackupApi
    else if method == "vacuum-into" then
      captureVacuumInto
    else
      throw "unknown sqlite backup method: ${method}";

  validateSnippet = mode:
    if mode == "quick" then
      validateQuickCheck
    else if mode == "integrity" then
      validateIntegrity
    else
      throw "unknown sqlite validation mode: ${mode}";

  mkBackupScript =
    { name
    , dbPath
    , destDir
    , method ? "backup-api"
    , keep ? 7
    , validateMode ? "quick"
    }:
    pkgs.writeShellScript "sqlite-backup-${name}" ''
      set -euo pipefail

      export PATH="${lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gawk
        pkgs.util-linux
        pkgs.sqlite
      ]}:$PATH"

      umask 077

      name=${lib.escapeShellArg name}
      db_path=${lib.escapeShellArg dbPath}
      dest_dir=${lib.escapeShellArg destDir}
      keep=${toString keep}

      mkdir -p "$dest_dir"

      lock="$dest_dir/.lock"
      exec 9>"$lock"
      flock -n 9 || exit 0

      ts="$(date +%Y%m%dT%H%M%S)"
      tmp_path="$dest_dir/$name.$ts.db.tmp"
      out_path="$dest_dir/$name.$ts.db"

      if [ ! -f "$db_path" ]; then
        printf '[sqlite-backup] source db missing: %s\n' "$db_path" >&2
        exit 1
      fi

      cleanup() {
        rm -f "$tmp_path"
      }
      trap cleanup EXIT

      rm -f "$tmp_path"

      ${captureSnippet method}

      ${validateSnippet validateMode}

      ${storeLocal}

      trap - EXIT

      ${retention}
    '';

in
{
  inherit mkBackupScript;
}
