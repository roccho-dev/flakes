---
name: managing-discussions
description: Coordinates a spec-to-oc-to-gpt discussion system for scoped design, evidence, dissent, prompt repair, decision-state, and backend execution. Use when managing approved discussion sources, collection progress, merge state, and execution readiness across multiple discussion sessions.
---

# Managing Discussions

Use this skill to drive a live `spec -> oc -> gpt` system from collection to
execution.

## Start Here

For live operation or resume-after-memory-loss, read `RUNBOOK.md` first.

`RUNBOOK.md` is the entry procedure for runtime state handling.
It requires the operator to create or update the live organization/state tables,
including the mandatory `member/url | goal | status` table on every run.

In those tables:

- `goal` is declarative and describes the desired end-state
- `status` is declarative and describes the currently verified state relative to
  that goal
- `status` may describe an intermediate state or the completed goal state
- `how to move next` belongs in transition or prompt tables, not in `goal`
  or `status`

This skill is structural and dynamic:

- runtime values stay outside the skill
- only the control model lives here
- session names, URLs, claim IDs, and source assignments belong to runtime state

## Runtime Model

```text
spec
  -> oc
    -> gpt
```

- `spec` owns the whole objective, final decisions, and execution.
- `oc` owns one scoped subset of the objective.
- `gpt` provides attributable external outputs.

Visibility rule:

- `spec` does not treat downstream `gpt` state as directly known unless `oc`
  has recovered and reported it
- `oc` is the reporting boundary between `spec` and downstream `gpt` sources
- when per-source content matters, `oc` must return source-readable reporting,
  not only merge-level conclusions

In live use, `spec` means the current managing operator/session using this
skill. It is not a separate hidden system.

## Delegation Bias

Default operating bias is GPT-heavy.

- treat `gpt` sessions as the primary place for content work
- when an approved `gpt` source can do the work, let it do the work there
- keep `oc` as close as possible to a control plane rather than a content
  plane

This includes a strong bias such as `~90% delegation` when the work is:

- table reconstruction
- option comparison
- dissent generation
- counterargument generation
- evidence restatement
- reformatting into required output sections

This does not mean `oc` gives up management responsibility.

`oc` remains responsible for:

- approved source control
- output contract enforcement
- weakness diagnosis
- resend decisions
- merge and decision-state updates
- lock/defer judgments
- backend execution verification

## Access Rules

Access from `oc` to `gpt` is controlled, not free-form.

- use only approved `gpt` sources
- prefer send-once and one-shot collection over repeated checking
- polling is exceptional and allowed only when explicitly approved for that run
- when waiting is needed, prefer a delayed one-shot check instead of a loop
- make transport/runtime blockers explicit in state
- do not hide repeated access behind vague status text

## Use This Skill When

- multiple discussion managers must be coordinated
- approved GPT sources must be tracked and constrained
- collection-state must advance into decision-state
- weak replies require prompt repair
- one candidate must be chosen and pushed toward execution

## Required Runtime State

Read `references/registries.md`.

At minimum, runtime must maintain:

- objective registry
- member registry
- source registry
- state registry
- prompt contract registry

When delegation strategy matters, also maintain:

- delegation policy registry

## Required State Machine

```text
source-selection
-> declaration-send-complete
-> response-collection
-> weakness-diagnosis
-> prompt-improvement
-> decision-grade-merge
-> implementation-lock
-> backend-execution
```

Every managed scope must move through this sequence.

## Required Tables

Read `references/tables.md`.

At minimum, every managed scope must produce:

- `member/url | goal | status`
- weakness table
- prompt improvement table
- merge table

When downstream `gpt` reporting matters, also produce:

- source report table

Evidence scopes must also produce:

- claim table
- evidence table
- decision impact table

The main state table is not a task list.

- `goal` says what must be true when the member is done
- `status` says what is true now, what is still missing, or what blocker is
  present
- `next required transition` is tracked separately

## Hard Rules

- Use only approved sources.
- If a new source is needed, raise `UNAPPROVED_SOURCE_REQUEST` first.
- Attribute merged results by `member/url`.
- Require dissent, not only support.
- Require claim-based evidence where implementation lock depends on theory.
- Prefer decision-grade outputs over suggestion-grade outputs.
- Weak replies must trigger diagnosis and prompt repair.
- Do not write `goal` as an instruction or operating step.
- Do not hide missing state behind vague `status` labels such as `incomplete`.
- Prefer delegating content work to approved `gpt` sources over recreating that
  work inside `oc`.
- Do not report downstream `gpt` state as if directly known unless it has been
  recovered into `oc`.
- When a decision depends on what specific `gpt` sources said, require
  source-readable per-source reporting, not merge-only reporting.
- Discussion is not done until at least one backend path executes.

## Recovery

Read `references/recovery.md` when:

- a source gives no reply
- a reply is broad but non-structured
- a source is blocked by runtime issues
- one weak source needs a stronger resend contract

## Typical Scope Classes

Read `references/examples.md`.

Typical scoped managers include:

- design scopes
- objection scopes
- backend stress scopes
- claim-evidence scopes
- counterevidence scopes

These are templates, not fixed instances.

## Decision-Grade Preference

Push sources toward outputs such as:

- `RECOMMENDED_OPTION`
- `WHY_THIS_SHOULD_BE_CHOSEN`
- `WHY_OTHER_OPTIONS_SHOULD_NOT_BE_CHOSEN_YET`
- `STRONGEST_OBJECTION`
- `DISCONFIRMING_EVIDENCE`
- `CHEAPEST_NEXT_TEST`

## Failure Signals

Treat these as failures:

- uncontrolled source growth
- no objection source
- broad survey replacing claim evidence
- many suggestions but no recommendation
- weak outputs without prompt repair
- backend execution deferred indefinitely

## Promotion Gate

Do not treat this skill as proven merely because the management model is well
written.

It should only be promoted as a stable skill after the workflow has actually
recovered the expected information from `oc` and `gpt` and driven at least one
backend path into execution.

## References

- `RUNBOOK.md`
- `references/registries.md`
- `references/tables.md`
- `references/recovery.md`
- `references/examples.md`
