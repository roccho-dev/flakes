# OpenCode DB Layout

This reference documents the files that mattered during runtime recovery on
`nixos-vm`.

## Data Root

Default data root:

```text
$XDG_DATA_HOME/opencode
```

Observed default on `nixos-vm`:

```text
/home/nixos/.local/share/opencode
```

## Important Files

| Path | Role |
|---|---|
| `opencode.db` | legacy or recovered SQLite store used by older flows during this incident |
| `opencode-stable.db` | SQLite store used by `opencode` 1.2.27 during this incident |
| `opencode.db-wal`, `opencode.db-shm` | SQLite side files for `opencode.db` |
| `opencode-stable.db-wal`, `opencode-stable.db-shm` | SQLite side files for `opencode-stable.db` |
| `auth.json` | auth state |
| `project/` | project snapshots or metadata |
| `storage/` | tool or runtime state |
| `tool-output/` | generated tool output |
| `log/` | runtime logs |

## Tables That Matter Most

| Table | Why it matters |
|---|---|
| `project` | root project identity and worktree path |
| `workspace` | workspace metadata; may be empty and still not be the root issue |
| `session` | session identity and project linkage |
| `message` | session messages |
| `part` | message parts; malformed JSON here can break `-s` and `export` |
| `todo` | session todo state |
| `session_share` | share metadata |
| `permission` | project permissions |
| `control_account` | account linkage |

## Current Path Hazard

During this incident:

- `opencode` 1.2.27 read `opencode-stable.db`
- recovered data initially lived only in `opencode.db`
- as a result, server APIs returned no sessions until the data was merged into
  `opencode-stable.db`

## Tooling Hazard

`parts/opencode/bin/ocdb-sync` currently defaults to:

- local: `.../opencode.db`
- peer: `/home/nixos/.local/share/opencode/opencode.db`

That means `ocdb-sync` may operate on a different DB than the current server if
newer `opencode` binaries use `opencode-stable.db`.
