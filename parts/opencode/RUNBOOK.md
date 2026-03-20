# OpenCode Runtime Runbook

Use this procedure when the `opencode` runtime on `nixos-vm` is unhealthy.

## 1. Capture the Current State

Check the service, version, listeners, and recent logs.

```bash
systemctl --user status opencode-home.service
journalctl --user -u opencode-home.service -n 80 --no-pager
ss -ltnp | rg ':(4096|9222|5900)\b'
/home/nixos/.nix-profile/bin/opencode --version
```

For the service binary version:

```bash
pid=$(systemctl --user show opencode-home.service -p MainPID --value)
child=$(pgrep -P "$pid" opencode | head -n1)
/proc/$child/exe --version
```

## 2. Determine the Actual Database Path

Do not assume the active binary uses `opencode.db`.

For a local CLI invocation:

```bash
opencode session list --print-logs 2>&1 | rg 'service=db path='
```

For the running server:

```bash
journalctl --user -u opencode-home.service -n 80 --no-pager | rg 'service=db path='
```

Observed during recovery:

- older CLI flows read `~/.local/share/opencode/opencode.db`
- `opencode` 1.2.27 read `~/.local/share/opencode/opencode-stable.db`

## 3. Snapshot Before Touching Anything

Capture the database file together with `-wal` and `-shm`.

```bash
ts=$(date +%Y%m%dT%H%M%S)
backup_dir="$HOME/.local/share/opencode-backup-$ts"
mkdir "$backup_dir"
cp -a "$HOME/.local/share/opencode/opencode.db"* "$backup_dir"/ 2>/dev/null || true
cp -a "$HOME/.local/share/opencode/opencode-stable.db"* "$backup_dir"/ 2>/dev/null || true
```

## 4. Check Integrity Before Repair

```bash
nix shell nixpkgs#sqlite -c sqlite3 "$HOME/.local/share/opencode/opencode.db" 'PRAGMA quick_check;'
nix shell nixpkgs#sqlite -c sqlite3 "$HOME/.local/share/opencode/opencode-stable.db" 'PRAGMA quick_check;'
```

## 5. Test Visibility at Three Layers

### SQLite layer

```bash
nix shell nixpkgs#sqlite -c sqlite3 -header -column "$HOME/.local/share/opencode/opencode.db" \
  "select id, title, directory, time_updated from session order by time_updated desc limit 10;"
```

### CLI layer

```bash
opencode session list | sed -n '1,12p'
opencode export <session-id> >/dev/null && echo EXPORT_OK
```

### Server layer

```bash
curl -sS http://127.0.0.1:4096/session | sed -n '1,40p'
curl -sS http://127.0.0.1:4096/session/<session-id> | sed -n '1,80p'
```

If SQLite works but the server API is empty, check whether the server is reading
`opencode-stable.db` while recovered data only exists in `opencode.db`.

## 6. Repair Order

### Case A: The database is malformed

Stop the service first.

```bash
systemctl --user stop opencode-home.service
```

Recover to a fresh file.

```bash
src="$HOME/.local/share/opencode/opencode.db"
out="$HOME/.local/share/opencode-backup-$ts/opencode.recovered.db"
nix shell nixpkgs#sqlite -c bash -lc "sqlite3 \"$src\" '.recover' | sqlite3 \"$out\""
nix shell nixpkgs#sqlite -c sqlite3 "$out" 'PRAGMA quick_check;'
```

Swap only after the recovered file verifies.

### Case B: A session exists but `-s` or `export` fails

Check malformed JSON rows.

```bash
sid='<session-id>'
nix shell nixpkgs#sqlite -c sqlite3 -header -column "$HOME/.local/share/opencode/opencode.db" \
  "select count(*) as invalid_messages from message where session_id='$sid' and json_valid(data)=0; \
   select count(*) as invalid_parts from part where session_id='$sid' and json_valid(data)=0;"
```

Inspect bad rows before deleting them.

```bash
nix shell nixpkgs#sqlite -c sqlite3 -header -column "$HOME/.local/share/opencode/opencode.db" \
  "select id, message_id, time_created, length(data) as len, substr(data,1,160) as prefix \
   from part where session_id='$sid' and json_valid(data)=0 order by time_created, id;"
```

If exactly one obviously empty or truncated row is the blocker, back up again and
remove only that row.

### Case C: The server API cannot see sessions, but SQLite and older CLI can

Compare table counts between `opencode.db` and `opencode-stable.db`.

```bash
for db in "$HOME/.local/share/opencode/opencode.db" "$HOME/.local/share/opencode/opencode-stable.db"; do
  echo "=== $db"
  nix shell nixpkgs#sqlite -c sqlite3 -header -column "$db" \
    "select count(*) as projects from project; \
     select count(*) as workspaces from workspace; \
     select count(*) as sessions from session; \
     select count(*) as messages from message; \
     select count(*) as parts from part;"
done
```

If `opencode-stable.db` is the active DB for the current binary and it is empty,
merge the recovered data into it.

```bash
stable="$HOME/.local/share/opencode/opencode-stable.db"
legacy="$HOME/.local/share/opencode/opencode.db"

nix shell nixpkgs#sqlite -c sqlite3 "$stable" <<SQL
PRAGMA foreign_keys=OFF;
ATTACH DATABASE '$legacy' AS legacy;
BEGIN IMMEDIATE;
INSERT OR IGNORE INTO project SELECT * FROM legacy.project;
INSERT OR IGNORE INTO workspace SELECT * FROM legacy.workspace;
INSERT OR IGNORE INTO permission SELECT * FROM legacy.permission;
INSERT OR IGNORE INTO control_account SELECT * FROM legacy.control_account;
INSERT OR IGNORE INTO session SELECT * FROM legacy.session;
INSERT OR IGNORE INTO session_share SELECT * FROM legacy.session_share;
INSERT OR IGNORE INTO todo SELECT * FROM legacy.todo;
INSERT OR IGNORE INTO message SELECT * FROM legacy.message;
INSERT OR IGNORE INTO part SELECT * FROM legacy.part;
COMMIT;
DETACH DATABASE legacy;
PRAGMA quick_check;
SQL
```

## 7. Restart and Verify

```bash
systemctl --user start opencode-home.service
systemctl --user status opencode-home.service
curl -sS http://127.0.0.1:4096/session | sed -n '1,40p'
curl -sS http://127.0.0.1:4096/session/<session-id> | sed -n '1,80p'
```

## 8. Client Attach Check

Use a client version that matches the server when investigating attach issues.

PowerShell example:

```powershell
$HostIp='100.124.250.91';$Port=4096;wsl -d NixOS -- bash -lc "NIXPKGS_ALLOW_UNFREE=1 nix run github:NixOS/nixpkgs/nixos-unstable#opencode --extra-experimental-features 'nix-command flakes' -- attach 'http://${HostIp}:${Port}'"
```

## 9. Incident Notes Worth Preserving

- `opencode` 1.2.27 used `opencode-stable.db` in this environment.
- `ocdb-sync` still defaults to `opencode.db` paths, so DB path assumptions can
  drift from the active server binary.
- `session list` can work while `-s` and `export` fail if a single `part.data`
  row contains invalid JSON.
- Silent systemd behavior is not enough evidence. Always check `status`,
  `journalctl`, and the server HTTP endpoints.
