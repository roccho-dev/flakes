---
name: opencode-runtime-recovery
description: Operates and repairs opencode runtime state on nixos-vm. Use when attach, session visibility, systemd behavior, SQLite integrity, or client/server version drift becomes the blocker.
---

# OpenCode Runtime Recovery

Use this skill when `opencode` itself is healthy enough to start, but runtime
state is not healthy enough to trust.

This skill is about runtime diagnosis and recovery, not feature development.

It covers:

- `opencode-home.service` behavior and verification
- client/server version drift
- actual database path detection
- `opencode.db` versus `opencode-stable.db`
- SQLite backup, recovery, and merge
- session visibility mismatches between CLI and server
- malformed session payload rows that break `-s` or `export`

## Start Here

Read `RUNBOOK.md` first.

Then use the reference docs only as needed:

- `references/db-layout.md`
- `references/recovery.md`
- `references/backup.md`
- `references/version-matrix.md`
- `references/failure-patterns.md`

## Core Rules

- Backup first. Do not touch a live `opencode` database without a timestamped
  copy.
- Stop `opencode-home.service` before database surgery.
- Determine the real database path from logs. Do not assume the active binary
  reads the same file as older tooling.
- Treat `opencode.db` and `opencode-stable.db` as separate stores until proven
  otherwise.
- Verify both local CLI behavior and server HTTP behavior after each change.
- If a session row exists but `-s` or `export` fails, inspect malformed JSON in
  `message.data` and `part.data` before changing metadata.
- Prefer reversible fixes: snapshot, inspect, repair, verify, then restart.

## Use This Skill When

- `opencode attach` connects but sessions are missing
- `opencode session list` and `opencode export` disagree
- the server API returns `[]` or `Session not found`
- SQLite reports `database disk image is malformed`
- a single session opens in DB queries but not in `opencode -s`
- `opencode-home.service` restarts, exits early, or behaves silently
- a client and server are on different `opencode` versions

## Working Bias

Current operator bias on `nixos-vm` is:

- confirm the active binary version first
- confirm the active DB path second
- verify the DB with SQLite before changing service configuration
- repair data before rewriting service behavior

## Verification Targets

A recovery is not done until all relevant layers agree:

- SQLite integrity is `ok`
- `opencode session list` works for the intended binary version
- `opencode export <session>` works for the intended binary version
- `GET /session` on the running server returns expected sessions
- `GET /session/<id>` returns the targeted session
- interactive attach can continue the expected session

## References

- `RUNBOOK.md`
- `references/db-layout.md`
- `references/recovery.md`
- `references/backup.md`
- `references/version-matrix.md`
- `references/failure-patterns.md`
