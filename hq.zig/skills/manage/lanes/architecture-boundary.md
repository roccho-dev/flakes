# Architecture Boundary Lane

## Only Scope

Responsibility boundaries for:

- `qjs`
- `hq.zig`
- `cdp-bridge.zig`
- `chromedevtoolprotocol.zig`

## Goal

Freeze temporary and final owners without mixing build-fix concerns.

## Freeze

- external view should converge toward `qjs + hq.zig`
- `qjs` owns live browser / DOM / UI / thread procedures
- `hq.zig` owns durable/app core and persistence boundary
- `cdp-bridge.zig` is internal transport
- `chromedevtoolprotocol.zig` is internal reusable Zig CDP library
- `qjs -> sqlite` direct write is forbidden

## Defer

- concrete ingest implementation
- tool rewrites
- build/test repair

## Next Entry Point

- Read `source-management.md`.
