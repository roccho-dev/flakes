{ pkgs }:

''
  "${pkgs.sqlite}/bin/sqlite3" "$db_path" <<SQLITE_EOF
.timeout 60000
VACUUM INTO '$tmp_path';
SQLITE_EOF
''
