# OpenCode Backup Guidance

## Rules

- Back up before inspect, not only before edit.
- Capture SQLite side files together with the main DB.
- Prefer SQLite `.backup` for routine snapshots.
- Store backups outside the repo checkout.
- Verify snapshots with `PRAGMA quick_check;`.

## Minimum Incident Backup

```bash
ts=$(date +%Y%m%dT%H%M%S)
backup_dir="$HOME/.local/share/opencode-backup-$ts"
mkdir "$backup_dir"
cp -a "$HOME/.local/share/opencode/opencode.db"* "$backup_dir"/ 2>/dev/null || true
cp -a "$HOME/.local/share/opencode/opencode-stable.db"* "$backup_dir"/ 2>/dev/null || true
```

## Preferred Routine Snapshot

Use `.backup` so SQLite provides a coherent copy.

```bash
src="$HOME/.local/share/opencode/opencode-stable.db"
out="$HOME/.local/share/opencode-backup-$ts/opencode-stable.snapshot.db"
nix shell nixpkgs#sqlite -c sqlite3 "$src" ".backup $out"
nix shell nixpkgs#sqlite -c sqlite3 "$out" 'PRAGMA quick_check;'
```

Repeat for `opencode.db` if the environment still uses both files.

## Suggested Retention

Start simple:

- hourly snapshots for 24 hours
- daily snapshots for 14 days
- weekly snapshots for 8 weeks

## Restore Rule

- stop `opencode-home.service`
- restore the intended DB file
- remove stale `-wal` and `-shm` if they do not belong to the restored DB
- verify with SQLite before starting the service again

## Current Caveat

Do not assume `ocdb-sync` and the active server target the same DB file.
Verify the active DB path first.
