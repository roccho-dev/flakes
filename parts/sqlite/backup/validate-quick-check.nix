{ pkgs }:

''
  qc="$("${pkgs.sqlite}/bin/sqlite3" "$tmp_path" "PRAGMA quick_check;")"
  if [ "$qc" != "ok" ]; then
    printf '[sqlite-backup] quick_check failed: %s\n' "$qc" >&2
    exit 1
  fi
''
