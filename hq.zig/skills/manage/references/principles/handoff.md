# Handoff

Status: partial

## Meaning

Downstream work should say what the next actor must verify or freeze, rather than
forcing them to reopen the entire reasoning chain.

## Rules

- include explicit `what oc should verify next`
- include explicit `what should be frozen now`
- include explicit `what remains blocked`

## Existing Reflection

- `RUNBOOK.md` already requires next action tables

## Missing Reflection

- no named handoff contract yet for downstream `gpt` outputs

## Completion Target

Handoff should be explicit enough that `oc` can verify, gate, and continue without
reconstructing the whole reasoning chain.

## Next Entry Point

- Read `../../lanes/architecture-boundary.md`.
