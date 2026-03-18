# DOM Model Gate (Pro)

Purpose
- Worker self-report is not sufficient to prove the active model is a Pro model.
- Gate worker usage on DOM-confirmed model label from the ChatGPT UI.

This gate is designed to choose correctness over availability: if the DOM signal
is missing or ambiguous, treat it as failure/unknown.

DOM Signals
- Model switcher button: `button[data-testid="model-switcher-dropdown-button"]`
  - `innerText` commonly contains a label like `ChatGPT 5.4 Pro`.
  - `aria-label` commonly contains `Model selector, current model is ...`.
  - Fallback selectors (if data-testid changes):
    - `button[aria-label*="Model selector" i]`
    - `button[aria-label*="current model" i]`
- Plan badge (supporting evidence): `[data-testid="accounts-profile-button"]` text may contain `Pro`.

Algorithm (QJS-first)
1) Read DOM model snapshot:
   - `model_text`: normalized `innerText` (fallback: `aria-label`).
   - `model_aria`: normalized `aria-label`.
   - `pro_model`: true iff `\bpro\b` matches `model_text` or `model_aria` (case-insensitive).
   - `pro_plan_badge`: true iff `\bpro\b` matches profile button text.
2) If the model switcher is not present immediately, use a bounded wait (MutationObserver + timeout)
   and re-read the snapshot.

Decisions
- Gate on `pro_model` (DOM) for "Pro model" eligibility.
- Treat missing model switcher (or empty label) as `unknown`.
- Plan badge is supporting evidence only (useful to debug auth/account issues).

Admission Points
- Thread-open gate: when automation opens a new tab/session, snapshot DOM model
  and alert if it is non-Pro/unknown.
- Pre-send gate: immediately before sending a prompt to a worker, snapshot DOM
  model again and fail closed if non-Pro/unknown.

Reconciliation With MODEL_CONFIRMATION
- `MODEL_CONFIRMATION` remains mandatory for worker blocks, but does not prove Pro.
- If DOM model label disagrees with worker `MODEL_CONFIRMATION MODEL=...`, emit a warning.
- If DOM `pro_model` is false/unknown, treat the worker as ineligible regardless of MODEL_CONFIRMATION.

Output/Alert Contract (current PoC)
- `parts/chromedevtoolprotocol/chromium-cdp.hq-threads.mjs`
  - Adds `dom_model` fields to `THREADS_STATUS.json` rows.
  - Renders a `dom_model` column in `THREADS_STATUS` Markdown.
  - `--requireDomPro` exits non-zero if any *open* thread is missing/non-Pro by DOM.
  - When auto-opening a thread (cdpNew/openOrFind), emits a stderr alert line:
    `DOM_MODEL_ALERT: non-Pro or unknown model after auto-open: <url> :: <label>`

- `parts/chromedevtoolprotocol/chromium-cdp.send-chatgpt.mjs`
  - `--requireDomPro` fails closed if the DOM model is non-Pro/unknown.
  - Records `dom_model_preflight` in stdout JSON.
  - If `--outDir <dir>` is provided, writes:
    - `<dir>/DOM_MODEL_PRE_SEND.json` (evidence snapshot + timestamp)
    - `<dir>/SEND_META.json` (machine-readable result)

Notes
- This is a QJS PoC intended to be embedded later if needed; do not block on a Zig port.

Policy Surface
- If we need to accept additional Pro-eligible labels that do not contain the
  word `Pro`, introduce a small explicit allowlist/mapping and version it.
  Keep it minimal to avoid silent broadening.

Viewport
- If the model switcher is hidden/not rendered due to viewport/layout, DOM model
  can become `unknown` and block work. Treat viewport as part of the automation
  contract.
