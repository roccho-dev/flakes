# ChatGPT CDP UX Hurdles

This document records the concrete UX and transport problems encountered while
using HQ's Chromium/CDP tooling against live ChatGPT threads.

It is intentionally operator-focused: what failed, why it likely failed, what
worked around it, and what should be improved in tooling and playbooks.

## Scope

- Browser: Chromium launched with remote debugging and a persisted profile.
- Display: Xvfb + x11vnc for temporary GUI recovery / login.
- CDP transport/tooling in this repo:
  - `parts/local/cdp-bridge.zig`
  - `parts/local/chromium-cdp.nix`
- Target application: ChatGPT web UI (thread pages, sidebar, search, composer).

## Summary

The instability was not caused by one bug alone. It came from the combination
of:

1. A minimal CDP transport (`cdp-bridge`) with little recovery logic.
2. A complex SPA target (ChatGPT) with virtualized DOM, async rendering,
   `contenteditable` composer behavior, and model/streaming state changes.
3. Long prompt injection / send workflows that are much more fragile than short,
   synchronous reads.

The practical lesson is:

- raw transport is not enough,
- ChatGPT-specific UI automation needs explicit recovery strategies,
- and operator playbooks must assume send/read asymmetry.

## Encountered Hurdles

### H1. Raw page-level CDP calls were intermittently unstable

Observed symptoms:

- `WouldBlock`
- `Promise was collected`
- timeouts on tabs that looked visually alive

Likely cause:

- `cdp-bridge` is intentionally a minimal helper and does not include retry,
  reconnection, or higher-level session stabilization.
- Reusing the same page websocket for a long sequence of ChatGPT operations made
  failures more likely.

Operational effect:

- direct `cdp-bridge call --ws ws://.../devtools/page/...` worked for quick
  reads, but became unreliable under repeated send/read cycles.

What worked better:

- fresh tabs
- shorter evaluations
- avoiding long `awaitPromise` flows when possible

### H2. ChatGPT composer is `contenteditable`, not a normal textarea

Observed symptoms:

- prompt text appeared in the composer but send did not become reliable
- one-shot DOM injection + click often failed silently

Likely cause:

- ChatGPT uses a ProseMirror-like `DIV[contenteditable=true]`
- visual DOM content and internal app state are not always synchronized by naive
  `innerHTML` assignment

Operational effect:

- `innerHTML`/`input` was not a trustworthy way to send large packets

What worked better:

- `document.execCommand('insertText', ...)` for short/medium prompts
- `Input.insertText` for some cases
- splitting the workflow into explicit stages (insert, wait, click, confirm)

### H3. Long prompt send is much less reliable than short prompt send

Observed symptoms:

- long markdown packets sometimes appeared partially in the editor
- compact versions sent successfully where full versions failed
- send button sometimes vanished or failed to resolve immediately after long
  insertion

Operational effect:

- long packet send should be treated as a higher-risk operation than short reads

What worked better:

- maintain both full and compact variants of operator packets
- use compact follow-up prompts when a thread only needs strict-format resend

### H4. Send button detection is timing-sensitive

Observed symptoms:

- `button[data-testid="send-button"]` sometimes existed only after a short wait
- in some tabs, send button resolution failed during injection but succeeded in a
  later step

Operational effect:

- one-step `inject + click` is brittle

What worked better:

- two-step flow:
  1. insert text
  2. short wait
  3. resolve send button
  4. click
  5. confirm newest user marker

### H5. Reused tabs and fresh tabs behaved differently

Observed symptoms:

- a reused thread tab could stop exposing prompt/send reliably
- the same thread, reopened in a fresh tab, could behave correctly again

Operational effect:

- retrying a bad tab is often worse than reopening the thread in a fresh tab

Recommendation:

- prefer fresh tab retry after repeated transport/UI failures

### H6. Thread reading is easier than search/UI-wide retrieval

Observed symptoms:

- direct thread DOM reads were relatively stable
- ChatGPT search UI was much harder to automate reliably
- sidebar traversal was more stable than search-driven retrieval

Operational effect:

- if thread IDs/URLs are already known, prefer direct thread opens
- use search only as a best-effort helper, not as the primary inventory source

### H7. Markers are mandatory for reliable confirmation

Observed symptoms:

- send success was often ambiguous from transport alone
- UI/transport could report partial success

Operational effect:

- a unique marker in the latest user message was the most reliable confirmation

Recommendation:

- every operator packet should contain a stable marker prefix
- every send workflow should end by checking the latest visible user message for
  that marker

### H8. `awaitPromise` is especially risky on ChatGPT pages

Observed symptoms:

- long async `Runtime.evaluate` bodies were more failure-prone than sync reads
- `Promise was collected` appeared in cases where equivalent shorter sync reads
  succeeded

Recommendation:

- prefer short synchronous evaluations
- use async page-side code only when it reduces total external round-trips

### H9. Session/process reliability matters as much as CDP logic

Observed symptoms:

- temporary browser sessions died and had to be rebuilt
- once rebuilt under user services, recovery became much easier

Operational effect:

- temporary manual browser launches are too fragile for repeated HQ operations

What worked better:

- user services for:
  - Xvfb
  - Chromium with persisted profile
  - x11vnc

## Why mjs / Zig Felt Unstable

This is not mainly about language quality.

### Zig / `cdp-bridge`

Strength:

- simple, durable, minimal transport helper

Weakness in this scenario:

- too low-level for ChatGPT-specific recovery
- no built-in retry/stabilization/session heuristics

### JS/QJS/mjs workflows

Strength:

- easier to express higher-level DOM workflows

Weakness in this scenario:

- heavily coupled to ChatGPT UI assumptions
- brittle under React/ProseMirror/virtualized DOM behavior

Therefore the real problem was:

- minimal transport on one side,
- fragile high-level UI automation on the other,
- and a difficult target application in the middle.

## Recommended Operator Strategy

1. Prefer direct thread reads over global/search UI operations.
2. Prefer short, synchronous DOM reads over long async page scripts.
3. For sending:
   - keep both full and compact packet variants
   - prefer two-step send over one-step send
   - confirm via latest-user marker, not transport success alone
4. If a tab becomes flaky, open a fresh tab for the same thread.
5. Treat search automation as best-effort, not authoritative inventory.

## Recommended Tooling Follow-Ups

### Transport/primitive layer

- add safer page-call retries around transient websocket failures
- distinguish transport failure vs. UI state failure in operator output
- provide a helper for fresh-tab retry with marker confirmation

### ChatGPT-specific workflow layer

- standardize send workflow:
  - prepare prompt
  - insert text
  - wait
  - click send
  - confirm marker
- support packet fallback order:
  - full
  - compact
  - follow-up compact

### Playbook/docs

- document fresh-tab preference for unstable threads
- document that long send is riskier than long read
- document marker confirmation as a required postcondition

## Non-Goals

- This document does not propose rewriting ChatGPT automation around arbitrary
  coordinate clicking.
- This document does not recommend adding polling loops to orchestration.
- This document does not recommend trusting worker self-report instead of DOM/UI
  evidence.
