{ pkgs }:

''
  ic="$("${pkgs.sqlite}/bin/sqlite3" "$tmp_path" "PRAGMA integrity_check;")"
  if [ "$ic" != "ok" ]; then
    printf '[sqlite-backup] integrity_check failed: %s\n' "$ic" >&2
    exit 1
  fi
''
