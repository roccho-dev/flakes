# Chrome Headless Lifecycle Lane

## Scope

This lane owns the headful/headless Chrome lifecycle for CDP automation:

- `chrome-profile-bootstrap.mjs` - headful login + profile management
- `chromium-cdp.lib.mjs` - headless detection and login state functions
- `chromium-cdp.nix` - Chrome launch configuration

## State Machine

```
[bootstrap] ──headful login──► [seed_profile]
                                        │
                                        ▼
                                  [publish]
                                        │
                                        ▼
                              [snapshot_profile]
                                        │
                                        ▼
[headless_automation] ◄── reuse ─── [runtime_copy]
                                        │
                                        ▼ (if degraded)
                              [headful_recovery]
```

## Lifecycle Phases

### Phase 1: Bootstrap (headful + login)

**When**: Initial setup or login recovery

**Steps**:
```bash
# 1. Start headful Chrome with VNC
systemd-run --user --unit chrome-login-9223 \
  /run/current-system/sw/bin/nix shell 'path:.#chromium-cdp' \
    nixpkgs#bash nixpkgs#coreutils ... -c bash -c '...'

# 2. Verify Chrome and login
qjs --std -m chrome-profile-bootstrap.mjs --action verify
qjs --std -m chrome-profile-bootstrap.mjs --action login-complete

# 3. Publish snapshot
qjs --std -m chrome-profile-bootstrap.mjs --action publish
```

**Profile paths**:
- Seed: `~/.secret/hq/chromium-cdp-profile-140`
- Snapshot: `~/.secret/hq/chromium-cdp-profile.snapshot`

### Phase 2: Headless Automation

**When**: Normal CDP operations

**Environment**:
```bash
export HQ_CHROME_HEADLESS=1
export HQ_CHROME_PROFILE_DIR=~/.secret/hq/chromium-cdp-profile.snapshot
export HQ_CHROME_ADDR=127.0.0.1
export HQ_CHROME_PORT=9222
```

**Code check**:
```javascript
import { isHeadlessMode, getChromeProfileDir } from "./chromium-cdp.lib.mjs";

if (isHeadlessMode()) {
  // Use snapshot profile
  const profileDir = getChromeProfileDir();
}
```

### Phase 3: Recovery (headful fallback)

**When**: Snapshot degraded (login-required, challenge-blocked, probe-failed)

**Detection**:
```javascript
import { detectLoginState } from "./chromium-cdp.lib.mjs";

const state = detectLoginState(wsUrl);
if (state.cloudflare || state.login_page) {
  // Need headful recovery
}
```

**Recovery steps**:
1. Stop headless Chrome
2. Start headful Chrome with seed profile
3. Manual login if needed
4. Publish new snapshot
5. Resume headless automation

## Architecture Boundary

| Layer | Owner | Responsibility |
|-------|-------|----------------|
| Chrome launch, profile lifecycle | `parts/chrome/**` | Service layer |
| Headless detection, login state | `chromium-cdp.lib.mjs` | qjs utilities |
| DOM polling, CDP automation | `qjs scripts` | ChatGPT UI operations |
| Durable state, SQLite | `hq.zig` | App core |

## Key Constraints

1. **Never reuse seed profile directly** - always copy to runtime
2. **Login is headful only** - no automated login
3. **Publish only after clean stop** - avoid profile corruption
4. **Profile snapshot is read-only in headless** - prevents race conditions

## Files

| File | Purpose |
|------|---------|
| `chrome-profile-bootstrap.mjs` | Headful login wrapper |
| `chromium-cdp.lib.mjs` | `isHeadlessMode()`, `detectLoginState()`, `waitForLogin()` |
| `chromium-cdp.nix` | `HQ_CHROME_HEADLESS=1` support |
| `chrome/RUNBOOK.md` | Detailed bootstrap procedures |

## Next Entry Point

- Read `polling_contracts.md` for ChatGPT response polling
- Read `architecture-boundary.md` for qjs/hq.zig boundary
