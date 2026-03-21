# Principles Index

This index records the operating principles used to manage live `spec -> oc -> gpt`
runs.

`status` means whether the principle is already strongly reflected in the manage
skill, only partially reflected, or still missing.

| principle | meaning | status | recorded in |
|---|---|---|---|
| goal/end-state first | define what done means before methods | partial | `goal-first.md` |
| state before prose | keep reusable tables ahead of narrative | existing | `goal-first.md` |
| current -> goal -> delta | plan from gap, not from local next-step only | partial | `current-goal-delta.md` |
| periodic current-state reanalysis | re-check assumptions, dependency anchors, and target end-state | missing | `current-goal-delta.md` |
| scope lock | fix the only active scope before asking for work | partial | `scope-and-non-goals.md` |
| non-goal declaration | say what is intentionally out of scope | missing | `scope-and-non-goals.md` |
| tool/task separation | separate target work from tooling repair | partial | `scope-and-non-goals.md` |
| full context first | give required source/env/runtime context up front | missing | `required-inputs.md` |
| runtime declaration | declare toolchain/platform/runtime expectations explicitly | missing | `required-inputs.md` |
| approved-source governance | use approved sources only; keep role boundaries explicit | existing | `source-governance.md` |
| one-shot access default | send once and collect once unless polling is approved | existing | `source-governance.md` |
| runtime vs inference split | keep confirmed runtime facts separate from inference | partial | `evidence-separation.md` |
| dissent first | ask for strongest objection before commitment | existing | `dissent.md` |
| staged completion | work through explicit completion stages | missing | `staged-completion.md` |
| phase report contract | each completed phase reports the same core fields | missing | `staged-completion.md` |
| artifact lineage | preserve baseline, patch lineage, and downloadable artifacts | missing | `artifact-lineage.md` |
| full verification before commit | do not treat unverified work as final | missing | `artifact-lineage.md` |
| freeze then redeclare | if the completion state changes, restate the whole picture | missing | `freeze-and-redeclaration.md` |
| explicit handoff | state what `oc` should verify next | partial | `handoff.md` |

## Rule

This directory is the canonical record of these principles.

`SKILL.md` holds the structural model.
`RUNBOOK.md` holds the entry procedure.
These files hold the behavioral constraints that keep `what` from being erased
by `how`.

## Next Entry Point

- Read `goal-first.md`.
