# OpenCode Failure Patterns

| Symptom | Likely meaning | First check | Likely action |
|---|---|---|---|
| `database disk image is malformed` | SQLite corruption | `PRAGMA quick_check;` | recover into a fresh DB |
| `Session not found` but DB row exists | wrong DB path or broken session payload | active DB path, `json_valid(data)` | merge into active DB or trim bad row |
| `JSON Parse error: Unexpected EOF` | truncated JSON payload in `message` or `part` | `json_valid(data)=0` | remove the bad row after backup |
| `GET /session` returns `[]` | server sees an empty or wrong DB | server logs for `service=db path=` | inspect `opencode-stable.db` versus `opencode.db` |
| `systemctl restart` is quiet but service disappears | clean early exit | `systemctl status`, `journalctl` | inspect wrapper and early-exit handling |
| attach shell misses expected commands | service env differs from login shell | process `PATH` and service wrapper | restart with explicit environment or login shell |
| `file.watcher ... libstdc++.so.6` | watcher binding failed | logs only | note it, but do not assume it caused DB loss |

## Important Incident-Specific Lessons

- Session visibility can fail at three different layers: SQLite, CLI, and server.
- A healthy `opencode.db` does not imply a healthy server if the server reads
  `opencode-stable.db`.
- `session list` is weaker proof than `export`, `-s`, and server API checks.
