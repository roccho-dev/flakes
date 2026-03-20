{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      backupLib = import ../sqlite/backup/lib.nix { inherit lib pkgs; };

      script = backupLib.mkBackupScript {
        name = "test";
        dbPath = "/tmp/sqlite-backup-src.db";
        destDir = "/tmp/sqlite-backup-dest";
        method = "backup-api";
        keep = 2;
        validateMode = "quick";
      };

      check =
        pkgs.runCommand "sqlite-backup-backup-api"
          {
            nativeBuildInputs = [
              pkgs.coreutils
              pkgs.sqlite
            ];
          }
          ''
            set -euo pipefail

            db=/tmp/sqlite-backup-src.db
            dest=/tmp/sqlite-backup-dest

            rm -f "$db"
            rm -rf "$dest"
            mkdir -p "$dest"

            "${pkgs.sqlite}/bin/sqlite3" "$db" <<'SQL'
            PRAGMA journal_mode=WAL;
            CREATE TABLE t(x);
            INSERT INTO t VALUES (1);
            SQL

            ${script}

            f="$(${pkgs.coreutils}/bin/ls -1 "$dest"/test.*.db | ${pkgs.coreutils}/bin/head -n 1)"
            test -f "$f"

            got="$("${pkgs.sqlite}/bin/sqlite3" "$f" "SELECT count(*) FROM t;")"
            test "$got" = "1"

            touch "$out"
          '';
    in
    {
      checks.sqlite-backup-backup-api = check;
    };
}
