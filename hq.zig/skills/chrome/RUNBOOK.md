# Runbook

Use this file when Chrome/CDP is the blocker and you need an operational
decision quickly.

## First Rule

Do not guess whether the issue is:

- launch method
- saved profile state
- fresh profile state
- headless/headful mode
- CDP endpoint reachability
- ChatGPT login/challenge state

Separate those explicitly.

For the exact pass/fail declarations, read `references/completion_gates.md`.

## One-Shot Rule

Do not poll by default.

Use a one-shot check for:

- process presence
- CDP endpoint reachability
- page state (`composer`, `login`, `challenge`)

Only repeat checks when the run explicitly approves it.

## Fast Triage

1. Check whether Chrome actually survives process launch.
2. Check whether `/json/version` and `/json/list` respond.
3. If launch is unstable, compare saved profile vs fresh profile.
4. If headless is unstable, try GUI on `Xvfb` and expose `x11vnc`.
5. Once logged in, prefer one-shot thread actions over repeated status loops.

## Launch Order

Prefer this order:

1. detached launch (`nohup`/equivalent), not plain `&`
2. fresh profile if saved profile is unstable
3. GUI/VNC fallback if login or challenge recovery is needed
4. saved profile reuse only after it proves stable again

## Attachment Recovery

If normal send works but attachments do not:

1. inspect `input[type=file]`
2. use file input or filechooser directly
3. do not block on the high-level send helper if the low-level attachment path
   is still available

## Current Working Split

- `qjs` owns dynamic ChatGPT operations
- `hq.zig` owns durable state and SQLite
- `cdp-bridge.zig` owns transport bridge behavior
- `chromedevtoolprotocol.zig` owns reusable Zig CDP primitives

## References

- `references/runtime_recovery.md`
- `references/completion_gates.md`
