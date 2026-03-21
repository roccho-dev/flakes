# Staged Completion

Status: missing

## Meaning

When a single turn cannot safely deliver the final state, work should advance by
named completion stages.

## Rules

- allow staged completion when needed
- each stage should declare its own completion state
- each stage should say what is complete, what is still incomplete, and what the
  next stage is

## Phase Report Contract

Preferred recurring fields:

- `PHASE_COMPLETED`
- `CHANGES_MADE`
- `RUNTIME_EVIDENCE`
- `ARTIFACTS`
- `REMAINING_BLOCKERS`
- `NEXT_PHASE`

## Completion Target

Staged completion should be a formal pattern rather than an ad hoc operator trick.

## Next Entry Point

- Read `artifact-lineage.md`.
