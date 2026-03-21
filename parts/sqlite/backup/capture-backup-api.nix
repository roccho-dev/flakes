{ pkgs }:

''
  "${pkgs.sqlite}/bin/sqlite3" "$db_path" <<SQLITE_EOF
.timeout 60000
.backup "$tmp_path"
SQLITE_EOF
''
