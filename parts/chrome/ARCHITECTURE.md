# Chrome Service Architecture

This document keeps the non-tool guidance that used to live in the Chrome skill.

## Scope

`parts/chrome/**` owns the Chrome/CDP runtime system:

- seed profile bootstrap
- published snapshot handoff
- runtime copy preparation
- headless launch
- browser/page health
- login/challenge classification
- explicit recovery entrypoints

It does not own the higher-level consult route.

## Ownership

| Area | Primary owner | Notes |
|---|---|---|
| Chrome launch, profile lifecycle, CDP health, runtime recovery | `parts/chrome/**` | Service layer |
| Dynamic DOM and UI choreography | `qjs` | ChatGPT selectors, send/read, attachment orchestration |
| Durable app state, queue, batch, SQLite | `hq.zig` | Keep durable logic out of DOM scripts |
| Low-level transport bridge | `cdp-bridge.zig` | Internal transport glue, not app core |
| Reusable Zig CDP primitives | `chromedevtoolprotocol.zig` | Stable dependency layer |

## Non-Goals For `parts/chrome/**`

- It does not implement the full consult route.
- It does not own attachment/send/read UI behavior.
- It does not own SQLite or durable app state.
- It does not permit `qjs -> sqlite` direct writes.

## Service Boundary

The service is complete when it can say, in machine-readable form:

- whether the browser process is alive
- whether browser CDP is healthy
- whether a target page is attachable
- whether app state is `logged-in`, `login-required`, `challenge-blocked`, or `probe-failed`

The consult route is a higher layer on top of that service.

## Replacement Note

The retired Chrome skill files are not required for build/runtime/tests once:

- the operational rules live in `parts/chrome/RUNBOOK.md`
- the runtime contracts live in `parts/chrome/config/*.json`
- the executable behavior lives in `parts/chrome/bin/*`
- the reusable checks live in `parts/chrome/test/*`

That migration is the intended state of this tree.
