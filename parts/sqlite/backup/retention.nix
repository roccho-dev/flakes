{ }:

''
  if [ "$keep" -gt 0 ]; then
    mapfile -t backups < <(ls -1t "$dest_dir"/"$name".*.db 2>/dev/null || true)
    if [ "''${#backups[@]}" -gt "$keep" ]; then
      for old in "''${backups[@]:$keep}"; do
        rm -f "$old"
      done
    fi
  fi
''
