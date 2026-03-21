# Chrome Skill Retirement Checklist

Use this checklist before deleting the retired Chrome skill files.

| ID | Check | Expected replacement |
|---|---|---|
| C1 | Runtime rules no longer require the skill text to operate | `parts/chrome/RUNBOOK.md` |
| C2 | One-shot vs polling behavior is encoded in the service contract | `parts/chrome/config/health.json`, `parts/chrome/hm.nix` |
| C3 | CDP/page/login/composer states are machine-readable | `parts/chrome/bin/chromedevtoolprotocol-service-health` |
| C4 | Seed/snapshot/runtime lifecycle is contract-defined | `parts/chrome/config/profile.json` |
| C5 | Bootstrap start/verify/login-complete/stop/publish are executable | `parts/chrome/bin/chromedevtoolprotocol-service-profile-bootstrap` |
| C6 | Bootstrap behavior has smoke coverage | `parts/chrome/test/profile-bootstrap-smoke-e2e.sh` |
| C7 | Single-session protection exists and is tested | `parts/chrome/bin/chromedevtoolprotocol-service*`, `parts/chrome/test/single-session-guard-e2e.sh` |
| C8 | Probe stratification and cooldown are tested | `parts/chrome/test/probe-policy-e2e.sh` |
| C9 | Ownership guidance still exists outside the retired skill | `parts/chrome/ARCHITECTURE.md` |
| C10 | `parts/chrome/**` does not refer back to the retired Chrome skill files as a runtime dependency | `git grep` on the repo |
| C11 | Build/runtime/tests do not rely on the retired Chrome skill files | `git grep` plus normal flake checks |
| C12 | Old fresh-vs-saved-profile wording is rewritten to seed/snapshot/runtime | `parts/chrome/RUNBOOK.md`, `parts/chrome/config/profile.json` |

Delete the old skill only when every row above is satisfied.
