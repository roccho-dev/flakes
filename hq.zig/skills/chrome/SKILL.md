---
name: chrome-runtime-recovery
description: Operates and recovers Chrome/CDP runtime paths for ChatGPT and HQ automation. Use when browser launch, profile reuse, GUI/VNC fallback, attachment flow, or CDP reachability become the blocker.
---

# Chrome Runtime Recovery

Use this skill when Chrome/CDP is the active blocker for automation or
consultation work.

This skill is about runtime and transport recovery, not discussion management.

It covers:

- Chrome launch method selection
- saved-profile vs fresh-profile recovery
- headless vs GUI/VNC fallback
- CDP endpoint reachability
- attachment/send/read operational recovery
- current component split between `qjs`, `hq.zig`, `cdp-bridge.zig`, and
  `chromedevtoolprotocol.zig`

## Start Here

For active use, read `RUNBOOK.md` first.

For the current accumulated knowledge, read:

- `references/runtime_recovery.md`

## Core Rules

- Prefer one-shot checks over polling by default.
- Treat launch method, profile state, and runtime block as separate failure
  classes.
- Do not assume a saved profile is healthier than a fresh one.
- Keep dynamic DOM and UI recovery in `qjs`.
- Keep durable state and SQLite ownership in `hq.zig`.
- Treat `cdp-bridge.zig` as a transport bridge, not as the app core.
- Treat `chromedevtoolprotocol.zig` as the reusable Zig CDP library.

## Current Architectural Bias

The current working split is:

- `qjs`: dynamic DOM, ChatGPT UI, operational orchestration
- `hq.zig`: SQLite, queue, batch, durable app logic
- `cdp-bridge.zig`: low-level CLI bridge for CDP transport
- `chromedevtoolprotocol.zig`: reusable Zig CDP primitives

Long-term, the desired visible shape is `qjs + hq.zig`, even if
`cdp-bridge.zig` still exists temporarily during the migration.

## Use This Skill When

- Chrome starts and immediately disappears
- `9222/9223` CDP reachability is unclear
- saved profile and fresh profile behave differently
- GUI or VNC is needed temporarily for login or challenge recovery
- attachments must be delivered and the normal send path is blocked
- `qjs` automation is healthy but transport is not
- transport is healthy but ChatGPT DOM flow is not

## References

- `RUNBOOK.md`
- `references/runtime_recovery.md`
