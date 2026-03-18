# Chromedevtoolprotocol Capability Matrix (2026-03-18)

Current proof state, refreshed against the live ChatGPT/CDP browser at `127.0.0.1:9222`.

## Summary

| Requirement | Script | Status | Fresh evidence |
|---|---|---|---|
| `project[] list/get` | `parts/chromedevtoolprotocol/chromium-cdp.project-inventory.mjs` | PROVEN | `/tmp/hq_project_inventory_recheck/PROJECT_INVENTORY.json` |
| `project.thread[] list/get` | `parts/chromedevtoolprotocol/chromium-cdp.project-inventory.mjs` | PROVEN | `/tmp/hq_project_inventory_recheck/PROJECT_INVENTORY.json` |
| `project.source[] create` | `parts/chromedevtoolprotocol/chromium-cdp.project-sources-promote-turn.mjs` | PROVEN | `/tmp/hq_e2e_promote/promote.json` |
| `project.source[] list/get` | `parts/chromedevtoolprotocol/chromium-cdp.project-sources-collect-files.mjs --findOnly` | PROVEN | `/tmp/hq_e2e_collect/findonly.json` |
| `thread.file download` | `parts/chromedevtoolprotocol/chromium-cdp.download-chatgpt-artifacts.mjs` | PROVEN | `/tmp/hq_e2e_thread_download/download.json` |
| `thread.file upload` | `parts/chromedevtoolprotocol/chromium-cdp.upload-chatgpt-file.mjs` | PROVEN | `/tmp/hq_e2e_upload/upload.json`, `/tmp/hq_e2e_upload/verify_turn.json` |
| `non-project thread -> project` | `parts/chromedevtoolprotocol/chromium-cdp.projectize-thread.mjs` | PROVEN | `/tmp/hq_e2e_projectize/projectize.json` |

## Composite flow proved

The following composite source flow is also green:

- upload local file into Project Sources
- ask a project thread to read it and echo the token
- download the same file back out

Evidence:

- `/tmp/hq_e2e_roundtrip/roundtrip.json`

## Notes

- The HQ worktree used for these checks is `repos/flakes/.worktrees/hq`.
- The flake in that worktree does not currently evaluate cleanly as-is, so the proofs were executed by running the committed QJS tools directly with:
  - `quickjs-ng`
  - `coreutils`
  - `repos/flakes#cdp-bridge`
- `chromium-cdp-tools` was updated to include `coreutils`, because several existing scripts already rely on `mkdir`/`cp` style utilities.
