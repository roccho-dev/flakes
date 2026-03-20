# UI Read/Get Timeouts (Notes)

Symptoms
- `hq ui read` / `hq ui get` may return `error: Timeout` even when CDP is reachable.
- Opening a fresh tab for the same thread URL often makes the next `hq ui read/get` succeed.

Likely Causes (working hypotheses)
- Target selection attaches to an existing tab matching the URL hint.
  - The chosen tab can be stale, mid-navigation, or otherwise not responding to `Runtime.evaluate`.
  - Multiple tabs with the same thread URL can exist; choosing the wrong one can cause timeouts.
- Page may be in a "generating" state or blocked state, which changes DOM availability and can delay evaluation.

Operational Mitigations (no Zig changes)
1) Prefer a fresh tab for the target URL before calling `hq ui read/get`:
   - `cdp-bridge new --addr 127.0.0.1 --port 9223 --url "<thread-url>"`
2) Avoid multiple open tabs for the same thread id.
3) Ensure the page is idle (no stop button) before extraction.

Future Mitigations (if we decide to change Zig)
- Add an option to force a new page/session for `hq ui read/get` (bypass attaching to existing targets).
- Add a fallback path: if attach/evaluate times out on an existing tab, open a new page and retry once.
