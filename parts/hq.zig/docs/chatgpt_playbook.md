# ChatGPT Orchestration Playbook (HQ)

This repo uses ChatGPT threads as "workers". The goal is to reliably turn
thread replies into deterministic artifacts (PATCH/REPORT/CHECKLIST) that can be
merged into the repo with minimal human intervention.

## Mental Model

- The *only* source of truth for what we are building is the repo worktree.
- ChatGPT threads are treated as untrusted, external workers.
- Every worker reply must be validated (format + constraints) before use.
- One-shot checks only (no polling loops). If unsure, request a new reply.

## Tools

- Zig CLI: `hq` (operator-facing, durable state owner)
  - Runs: status/send/collect + later ui read/get
- QJS helper (debug + status table):
  - `parts/chromedevtoolprotocol/chromium-cdp.hq-threads.mjs`

## Always-Run Workflow (Operator)

1) Print the thread table (copy into your report)

   - `qjs --std -m parts/chromedevtoolprotocol/chromium-cdp.hq-threads.mjs --statusOnly --requireDomPro`
   - If it prints `MODEL_CONFIRMATION_WARN` or `DOM_MODEL_WARN`, do not proceed.
     Fix the worker thread (active model must be Pro) and ask workers to repost.

2) Send instructions to workers (base + constraints)

   - Include base reference (zip + sha256) and scope boundaries.
   - Require `MODEL_CONFIRMATION` and strict output contract (see below).
   - Ensure the active model is Pro via DOM at send time (use `--requireDomPro` where available).

3) Collect artifacts

   - Collect only after the worker reply is complete.
   - Validate: model confirmation + required headings + section markers.

4) Integrate

   - Apply patch to SSOT base.
   - Run tests.
   - Produce a new base bundle + sha256.

5) Update ledger/base

   - Publish new bundle + sha256.
   - Update all worker instructions to reference the new base.

## Hard Rules

- NO POLLING: do not loop "sleep and check" in orchestration.
- Do not trust UI coordinates; prefer semantic DOM operations.
- Never accept artifacts without `MODEL_CONFIRMATION`.
- Keep high-conflict files single-owner per cycle (e.g. `parts/hq.zig/build.zig`).
- Pro gating is DOM-based (see `parts/hq.zig/docs/dom_model_gate.md`). Do not trust worker self-report.

## MODEL_CONFIRMATION (Mandatory)

Every worker reply must include this line:

`MODEL_CONFIRMATION: Pro=YES | MODEL=<exact label from the UI>`

It MUST be the first non-empty line of the newest assistant message.

If Pro/model cannot be confirmed, the worker must say:

`MODEL_CONFIRMATION: Pro=NO | MODEL=UNCONFIRMED`

and STOP (no further content).

## Output Contracts

### Design Review Contract

If the task is a design review, the reply must include these headings in this
exact order:

- RECOMMENDATION
- PLAN
- DELTA_ZIG
- DELTA_JS
- FINAL_TREE
- REQUIREMENTS
- SPECS
- TESTS
- CHECKLIST (YES/NO)

### Code/Artifact Contract

If the task is to deliver code artifacts, the newest assistant message must
contain a strict envelope:

BEGIN_WORKER_BLOCK
PATCH.diff
```diff
... unified diff ...
```
TEST_REPORT_worker
```text
... report ...
```
CHECKLIST
```text
... checklist ...
```
END_WORKER_BLOCK

Notes:
- Code fences are optional; if present they must match the section type.
- The extractor only accepts a canonical worker block after the MODEL_CONFIRMATION prologue.
- If the newest assistant message contains marker examples in prose, they must not be selected.
- Extraction must only scan the latest visible assistant tail (virtualization
  safe).

Operational contract:
- `hq ui get --outDir` must point to an empty directory (command fails otherwise).
