# GPT Request Contracts

Use this reference when `oc` sends work to `gpt` and expects outputs that are
meant to drive execution rather than broad discussion only.

This file does not replace `SKILL.md` or `RUNBOOK.md`.
It defines the request-side contract that improves output quality, handoff,
artifact lineage, and reuse after memory loss.

## Goal-First Rule

When asking `gpt` to do substantive work, declare the expected completion state.

Do not rely on vague requests such as:

- "analyze this"
- "help fix this"
- "look into this"

Prefer requests that say what must be true when the turn is done.

Examples:

- `the reply must identify one confirmed blocker and one first patch`
- `the reply must separate runtime-confirmed facts from static inference`
- `the reply must produce a downloadable diff and latest snapshot`

## Scope Lock Rule

Every request should explicitly say:

- the exact tree, file set, or artifact set in scope
- what is out of scope
- whether the source may widen scope on its own

Good examples:

- `only the hq.zig tree`
- `only build.zig and unit-suite wiring`
- `do not redesign parts/cdp in this turn`

## Runtime Declaration Rule

If runtime execution matters, declare the runtime contract explicitly.

At minimum, include:

- expected toolchain/runtime version
- expected platform or architecture when relevant
- whether execution is required or optional
- what to do if execution is unavailable

Good examples:

- `use Zig 0.16.0-dev.2915+065c6e794`
- `Ubuntu x86_64 is the intended environment`
- `if runtime execution is unavailable, say so and switch to static review`

## Evidence Separation Rule

Prefer output contracts that force `gpt` to separate:

- runtime-confirmed facts
- static inference
- unresolved gaps

Recommended section names include:

- `CONFIRMED_RUNTIME_FACTS`
- `STATIC_INFERENCE`
- `NOT_CONFIRMED`
- `CORRECTED_RUNTIME_STATEMENT`

This prevents suggestion-grade output from being mistaken for evidence-grade
output.

## Patch-Lineage Rule

When the work is patch-producing, prefer recoverable artifact lineage.

If the environment supports it, request:

- `git init` in the unpacked work tree
- a baseline commit
- one commit per patch step or patch milestone

If Git is not available, request both:

- a downloadable patch diff
- a downloadable full latest snapshot

Recommended section names include:

- `BASELINE_COMMIT_STATUS`
- `CURRENT_PATCH_COMMIT_STATUS`
- `DOWNLOADABLE_DIFF_ARTIFACT`
- `DOWNLOADABLE_SNAPSHOT_ARTIFACT`

## Handoff Rule

When `oc` or `spec` must continue after `gpt`, require explicit handoff fields.

Recommended section names include:

- `WHAT_OC_SHOULD_CONFIRM_NEXT`
- `MINIMAL_VERIFY_SEQUENCE`
- `IF_STILL_BLOCKED`

These should say what the next actor must verify, not re-open the whole
discussion.

## Owned-Route Rule

If `gpt` is the primary analysis-and-fix source for a scope, say so directly.

Examples:

- `gpt owns blocker selection and patch ordering`
- `oc only verifies and manages git`

This reduces unproductive convergence pressure when a local parallel path exists.

## Access Discipline Rule

Request/response traffic should follow the access rules from `SKILL.md`:

- send once by default
- prefer one-shot collection over repeated checking
- only use polling when that run explicitly approved it

When waiting is needed, ask for a result format that is robust to delayed
collection.

## Default Request Skeleton

```text
GOAL
- declare the expected completion state

SCOPE
- exact files/tree/artifacts in scope
- exact non-goals

RUNTIME
- toolchain/version/platform
- whether execution is required
- fallback if execution is unavailable

OUTPUT CONTRACT
- runtime-confirmed facts
- static inference
- first blocker
- patch series
- first patch
- minimal verify sequence
- handoff to oc/spec

ARTIFACT CONTRACT
- baseline commit or explicit no-git statement
- downloadable diff artifact
- downloadable latest snapshot
```

## Use This Reference When

- downstream `gpt` output is expected to drive implementation
- runtime claims need to be auditable
- patch lineage matters
- `oc` handoff needs to be low-friction
- the run may need to resume after memory loss
