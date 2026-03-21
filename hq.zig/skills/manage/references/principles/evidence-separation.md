# Evidence Separation

Status: partial

## Meaning

Separate what was actually confirmed from what is only inferred.

## Rules

- distinguish runtime-confirmed facts from static inference
- distinguish recovered source content from operator reconstruction
- do not let confidence leak across that boundary

## Existing Reflection

- `RUNBOOK.md` says source report tables must use recovered source content only
- `tables.md` supports per-source reporting

## Missing Reflection

- no standard output contract yet forces a `runtime facts vs inference` split

## Completion Target

Managed runs should use explicit sections or tables for:

- confirmed runtime facts
- static inference
- not-confirmed gaps

## Next Entry Point

- Read `dissent.md`.
