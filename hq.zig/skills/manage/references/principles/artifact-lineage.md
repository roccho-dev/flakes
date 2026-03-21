# Artifact Lineage

Status: missing

## Meaning

When downstream work produces patches or code, the artifact lineage should remain
recoverable.

## Rules

- prefer baseline commit + per-patch commit when Git is available
- if Git is unavailable, require both a downloadable diff and a downloadable full snapshot
- do not treat work as final before the declared verification gate is met

## Completion Target

Artifact-consuming lanes should be able to answer:

- what was the baseline
- what changed
- what the latest snapshot is
- whether verification gates are already satisfied

## Next Entry Point

- Read `freeze-and-redeclaration.md`.
