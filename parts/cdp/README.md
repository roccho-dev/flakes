# cdp

Repo-local CDP helpers, QJS scripts, and Nix glue.

This directory is not the `chromedevtoolprotocol.zig` dependency itself.
`parts/hq.zig` consumes the Zig module from `chromedevtoolprotocol.zig/`, while
`parts/cdp` contains the local operational tooling around it.

## Pre-Zig Policy

These `.mjs` tools are treated as pre-Zig artifacts. Their current language is
temporary; their eventual ownership boundary is not.

- If a script is converging on reusable CDP primitives, it should eventually
  move into `chromedevtoolprotocol.zig/` as Zig code or as tests/examples around
  that module.
- If a script is converging on ChatGPT automation, HQ worker orchestration, or
  other app-specific behavior, it should eventually move into `parts/hq.zig/`
  as Zig code.

## Current Split

- More likely `chromedevtoolprotocol.zig/` material
  - `chromium-cdp.lib.mjs`
  - `cdp-bridge.zig`
  - `chromium-cdp.nix`
- More likely `parts/hq.zig/` material after Zig porting
  - `chromium-cdp.send-chatgpt.mjs`
  - `chromium-cdp.read-thread.mjs`
  - `chromium-cdp.download-chatgpt-artifacts.mjs`
  - `chromium-cdp.projectize-thread.mjs`
  - `chromium-cdp.project-*.mjs`
  - `chromium-cdp.hq-threads.mjs`
  - `hq-dom-model.mjs`
  - `hq-run-manifest.mjs`
  - `hq-check-ascii.mjs`

The key rule is: do not move a pre-Zig script solely because it uses CDP. Move
it according to where the Zig implementation should finally live.
