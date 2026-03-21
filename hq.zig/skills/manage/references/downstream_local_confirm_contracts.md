# Downstream Local Confirm Contracts

Use this file when a downstream `oc` stream is responsible for turning upstream
`gpt` outputs into local truth.

## Core Rule

If a downstream local confirm stream exists, self-check alone is not `done`.

Self-check is upstream evidence.
Downstream local confirm is downstream truth.

## Role Split

| stream | role |
|---|---|
| `gpt` | upstream analysis, patching, artifact generation, self-check evidence |
| `oc` | downstream local confirm, adoption gate, local truth |
| `spec` | objective, state, approval, and final completion judgment |

## Required Upstream Handoff

At minimum, upstream should provide:

- scope declaration
- artifact lineage
- self-checked runtime facts
- verify sequence
- what downstream should confirm next

## Required Downstream Report

Every downstream local confirm run should return:

```text
STREAM_ROLE_UNDERSTOOD
LOCAL_CONFIRMED_NOW
FIRST_FAILING_OR_GREEN
GATE_DECISION
NEXT_REQUIRED_INPUT
DONE_CONDITION_UNDERSTOOD
```

## Gate Meanings

Use explicit gate values:

- `adopt`
- `hold`
- `reject`

Do not replace these with vague summaries.

## Done Condition

When a downstream local confirm stream exists, use this rule:

- upstream `self-checked` = accepted upstream evidence only
- downstream `local-confirmed` = accepted downstream truth
- `done` = downstream local green for the intended scope, or an explicit scoped
  gate decision that marks the remaining scope as intentionally deferred

## Verify Discipline

Downstream local confirm should:

- start from the smallest approved verify sequence
- stop at the first failing command when the goal is diagnosis
- continue only when the run contract says to continue past first failure
- report exact commands, exit codes, and stdout/stderr summaries when relevant

## Transfer Mismatch Rule

When upstream claims do not transfer downstream:

- do not collapse the mismatch into "still broken"
- report the first exact downstream mismatch
- send that mismatch back upstream as a new confirmed downstream runtime fact

## Next Entry Point

- Read `target_session_contracts.md`.
