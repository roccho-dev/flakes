# hq-zig-app

Single-binary Zig replacement for the non-E2E HQ path.

This app lives under `parts/hq.zig` and depends on the `chromedevtoolprotocol.zig` Zig module.

The repo-local CDP helpers and Nix glue live under `parts/cdp`; those are support
tools around the dependency, not the dependency itself.

Several ChatGPT/HQ automation scripts still live there as pre-Zig tooling. When
they are ported, they should land in `parts/hq.zig` unless they collapse into
generic reusable CDP primitives.

## Module layout

From `parts/hq.zig`, the build script looks for CDP in these layouts, in order:

- `../../chromedevtoolprotocol.zig/src/root.zig`
- `../../cdp/chromedevtoolprotocol.zig/src/root.zig`
- `../../../cdp/chromedevtoolprotocol.zig/src/root.zig`

You can also override discovery explicitly:

- `zig build -Dcdp-root=../../chromedevtoolprotocol.zig/src/root.zig`

## Baseline x86_64 builds

For Linux / WSL distribution builds, use a baseline CPU target to avoid
`SIGILL` on older or more restricted x86_64 environments.

Recommended commands:

- `zig build test-hq -Dcpu=baseline`
- `zig build -Dcpu=baseline`
- `zig-out/bin/hq --help`

The build script also defaults plain `zig build` to a baseline CPU model, but
passing `-Dcpu=baseline` explicitly is recommended for release automation and
README-copyable commands.

## ChatGPT orchestration

This repo uses ChatGPT threads as workers. The shared mental model and strict
output contracts live in `docs/chatgpt_playbook.md`.

Quick access:

- `zig-out/bin/hq playbook`
