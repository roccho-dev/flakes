# ADR-0001: Non-Regression Gate For Contract Bundles

Status: Accepted

## Context

We are integrating multiple Nemo/strict-contract bundles while preserving the behavior of existing implementations.

The requirement is "no regressions" (non-regression): existing implementations must keep producing the same observable results under the same inputs.

Truth source remains final-only: the public runtime base and normative contract surface are owned by the final-only bundle.

Baselines are *regression oracles* (not truth sources): a frozen observable corpus produced under fixed fixtures and a fixed `nmo` identity, used to mechanically detect behavior drift.

## Decision

We add an executable non-regression gate to this repo:

- `test/non_regression/bin/meta_gate.sh` runs each bundled suite in an isolated temporary copy.
- The gate captures observable artifacts (`results/` plus runner stdout/stderr/exit code).
- Outputs are normalized to remove path-dependent noise.
- The gate fails if normalized outputs differ from the checked-in baselines.

Current bundles covered:

- `bundles/contract_frontend_final_only`
- `bundles/contract_frontend_semantic_ir_tdd_ruleified`
- `bundles/contract_frontend_semantic_ir_tdd_nextgen_work`

Bundle roles (truth vs protection):

- A: `bundles/contract_frontend_final_only` is the public hard blocker and the only truth source.
- B: `bundles/contract_frontend_semantic_ir_tdd_ruleified` is a semantic regression sentinel (blocking during integration).
- C: `bundles/contract_frontend_semantic_ir_tdd_nextgen_work` is a cutover admission sentinel (blocking during integration).

Baselines are updated only via an explicit flag:

- `--write-baseline` overwrites baselines after a successful run.

## Consequences

- Integration work can proceed with a mechanical guarantee that the existing bundles remain stable.
- Any intended behavior change requires an explicit baseline update, making changes auditable.
- Baselines are repository data; they must remain TSV/DSV/text artifacts (no narrative translation by tooling).

## Non-Goals

- This gate does not decide architectural "truth source" policy beyond the observable corpus.
- This gate does not introduce new runner entrypoints or rewrite bundle internals.

## Follow-ups

- Add machine-readable baseline manifests (inputs digest, corpus digests, resolved `nmo` identity, normalization version).
- Add mechanical governance for baseline updates (rationale + affected-scope enforcement).
- Add schema/semantics and profile-boundary guards for the final-only public contract surface.
- Add CI wiring to run `nix build .#checks.<system>.contract-non-regression` on every change.
