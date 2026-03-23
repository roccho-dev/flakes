# Architecture Boundary Lane

## Only Scope

Responsibility boundaries for:

- `qjs`
- `hq.zig`
- `cdp-bridge.zig`
- `chromedevtoolprotocol.zig`
- `orchestrator.mjs`
- `cdp-results-to-sqlite.mjs`

## Goal

Freeze temporary and final owners without mixing build-fix concerns.

## Freeze

| Component | Owner | Responsibility |
|-----------|-------|----------------|
| `qjs` | qjs scripts | Live browser / DOM / UI / thread procedures |
| `hq.zig` | hq.zig | Durable/app core and persistence boundary |
| `cdp-bridge.zig` | internal | CDP HTTP+WebSocket transport |
| `chromedevtoolprotocol.zig` | internal | Reusable Zig CDP primitives |
| `orchestrator.mjs` | qjs | 3-store correlation and checkpoint management |
| `cdp-results-to-sqlite.mjs` | qjs | CDP results → SQLite persistence |

### Critical Rules

1. **`qjs -> sqlite` direct write is forbidden**
   - Use CLIexec bridge: qjs → sqlite3 CLI → SQLite
   - See: `cdp-results-to-sqlite.mjs` pattern

2. **DOM polling requires polling_contracts.md compliance**
   - All polling runs must declare: POLL_SCOPE, POLL_SUCCESS_CONDITION, POLL_INTERVAL, POLL_JITTER, POLL_CAP, POLL_STOP_CONDITIONS, POLL_REPORT_CONTRACT
   - See: `polling_contracts.md`

3. **Headless automation requires profile snapshot**
   - Bootstrap: headful login + publish snapshot
   - Automation: headless mode with snapshot reuse
   - Recovery: headful fallback
   - See: `chrome-headless-lifecycle.md`

4. **3-store correlation via orchestrator.mjs**
   - `local_agent_session_sqlite` (opencode managed)
   - `cdp_agent_session_sqlite` (CDP results cache)
   - `orchestrator_meta_sqlite` (correlation + checkpoint)
   - See: `orchestrator.mjs`

## Defer

- concrete ingest implementation (see orchestrator.mjs for current state)
- tool rewrites
- build/test repair

## Related Lanes

| Lane | Purpose |
|------|---------|
| `chrome-headless-lifecycle.md` | Headful/headless Chrome lifecycle |
| `source-management.md` | Source governance |
| `polling_contracts.md` | Polling contract specification |

## Next Entry Point

- Read `chrome-headless-lifecycle.md` for headless automation
- Read `polling_contracts.md` for DOM polling
- Read `source-management.md` for source governance
