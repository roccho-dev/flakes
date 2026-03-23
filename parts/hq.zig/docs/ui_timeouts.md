# UI Read/Get Timeouts (Notes)

## Symptoms

- `hq ui read` / `hq ui get` may return `error: Timeout` even when CDP is reachable.
- Opening a fresh tab for the same thread URL often makes the next `hq ui read/get` succeed.

## Likely Causes (working hypotheses)

- Target selection attaches to an existing tab matching the URL hint.
  - The chosen tab can be stale, mid-navigation, or otherwise not responding to `Runtime.evaluate`.
  - Multiple tabs with the same thread URL can exist; choosing the wrong one can cause timeouts.
- Page may be in a "generating" state or blocked state, which changes DOM availability and can delay evaluation.

## Operational Mitigations (no Zig changes)

1. Prefer a fresh tab for the target URL before calling `hq ui read/get`:
   ```bash
   cdp-bridge new --addr 127.0.0.1 --port 9223 --url "<thread-url>"
   ```
2. Avoid multiple open tabs for the same thread id.
3. Ensure the page is idle (no stop button) before extraction.
4. Use polling with `--poll-success-condition stop_button_gone`:
   ```bash
   qjs --std -m chromium-cdp.read-thread.mjs \
     --url "https://chatgpt.com/c/<thread>" \
     --poll-success-condition stop_button_gone \
     --poll-interval-min 3000 \
     --poll-interval-max 8000 \
     --poll-cap-tries 20
   ```

## Headful/Headless Switching

### Initial Login (headful required)

```bash
# 1. Start headful Chrome with VNC
systemd-run --user --unit chrome-login-9223 ...

# 2. Verify login complete
qjs --std -m chrome-profile-bootstrap.mjs --action login-complete

# 3. Publish snapshot
qjs --std -m chrome-profile-bootstrap.mjs --action publish
```

### Normal Automation (headless)

```bash
export HQ_CHROME_HEADLESS=1
export HQ_CHROME_PROFILE_DIR=~/.secret/hq/chromium-cdp-profile.snapshot
```

Check mode in code:
```javascript
import { isHeadlessMode } from "./chromium-cdp.lib.mjs";
if (isHeadlessMode()) {
  // Use snapshot profile for headless automation
}
```

### Login State Detection

```javascript
import { detectLoginState } from "./chromium-cdp.lib.mjs";

const state = detectLoginState(wsUrl);
if (state.cloudflare) {
  // Need headful recovery
}
if (state.login_page) {
  // Not logged in
}
```

## Polling Contracts

For ChatGPT response polling, use `read-thread.mjs` with polling contracts:

| Argument | Purpose |
|----------|---------|
| `--poll-scope` | What we're polling for |
| `--poll-success-condition` | When to stop polling |
| `--poll-interval-min/max` | Interval range |
| `--poll-jitter` | Random jitter per iteration |
| `--poll-cap-tries` | Maximum tries |
| `--poll-cap-duration` | Maximum duration |
| `--poll-stop-cloudflare` | Stop on Cloudflare challenge |
| `--poll-stop-login` | Stop on login required |
| `--poll-stop-ratelimit` | Stop on rate limit |

See: `polling_contracts.md` for full specification.

## Future Mitigations (if we decide to change Zig)

- Add an option to force a new page/session for `hq ui read/get` (bypass attaching to existing targets).
- Add a fallback path: if attach/evaluate times out on an existing tab, open a new page and retry once.
