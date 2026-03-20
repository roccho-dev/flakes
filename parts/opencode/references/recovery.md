# OpenCode Recovery Patterns

## Pattern 1: SQLite Corruption

Symptom:

- `database disk image is malformed`
- `PRAGMA quick_check;` reports corruption

Response:

1. stop `opencode-home.service`
2. back up DB plus `-wal` and `-shm`
3. run `.recover` into a fresh database
4. validate the recovered file with `PRAGMA quick_check;`
5. swap only after validation

Example:

```bash
src="$HOME/.local/share/opencode/opencode.db"
out="$HOME/.local/share/opencode-backup-$ts/opencode.recovered.db"
nix shell nixpkgs#sqlite -c bash -lc "sqlite3 \"$src\" '.recover' | sqlite3 \"$out\""
```

## Pattern 2: Session Row Exists but `-s` or `export` Fails

Symptom:

- `session list` shows the session
- `opencode -s <id>` or `opencode export <id>` fails
- stack trace mentions JSON parse failure or `Unexpected EOF`

Likely cause:

- one malformed JSON row in `message.data` or `part.data`

Response:

1. query invalid rows with `json_valid(data)=0`
2. inspect exact bad rows
3. back up again
4. remove only the bad row when it is clearly truncated or empty
5. verify `export` and `-s`

## Pattern 3: Server API Shows No Sessions

Symptom:

- `GET /session` returns `[]`
- `GET /session/<id>` returns `NotFound`
- SQLite still contains sessions

Likely cause:

- server binary is reading a different DB path than the one you repaired

Response:

1. capture DB path from server logs
2. capture DB path from the target client version with `--print-logs`
3. compare table counts between candidate DB files
4. merge recovered data into the DB that the active server actually uses

## Pattern 4: Service Starts Then Dies Cleanly

Symptom:

- `systemctl restart` appears quiet
- service becomes `inactive (dead)` shortly after start
- exit code is `0`

Response:

1. inspect `systemctl status`
2. inspect `journalctl --user -u opencode-home.service`
3. inspect wrapper behavior in `parts/opencode/hm.nix`
4. if needed, treat too-early clean exit as failure so systemd retries

## Pattern 5: Attach Still Fails After Data Repair

Symptom:

- DB looks healthy
- server sees sessions
- attach still misbehaves

Response:

1. verify client version
2. verify server version
3. retest with a matching client version
4. only then continue transport or UI debugging
