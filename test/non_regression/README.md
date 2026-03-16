# Non-Regression Gate (A/B/C)

This directory hosts a strict non-regression gate for the currently bundled contract suites.

Covered bundles:

- `bundles/contract_frontend_final_only` (`bin/run_all.sh`)
- `bundles/contract_frontend_semantic_ir_tdd_ruleified` (`bin/run_red_green.sh`)
- `bundles/contract_frontend_semantic_ir_tdd_nextgen_work` (`bin/check_nextgen_cutover.sh`)

Run (compare vs baseline):

```bash
test/non_regression/bin/meta_gate.sh
```

Run without installing `nmo` globally (recommended):

```bash
nix shell .#nmo -c test/non_regression/bin/meta_gate.sh
```

Initialize or intentionally update baselines:

```bash
test/non_regression/bin/meta_gate.sh --write-baseline
```

Baseline updates require a rationale row:

```bash
# Add a new last row (who/why/scope).
printf 'you\tupdate baselines for reason\tcontract_frontend_final_only\tmeta/\n' >> test/non_regression/rationale.tsv

# Then run the update.
test/non_regression/bin/meta_gate.sh --write-baseline
```

`affected_scope_labels` is a comma-separated list of bundle labels, or `ALL`.
`affected_scope_paths` is a comma-separated list of baseline-relative path prefixes,
or `ALL`.

Notes:

- The gate runs bundles in a temporary copy to avoid mutating the git worktree.
- Path-dependent text outputs are normalized (bundle root, repo root, home, nmo path).
- `nmo` resolution follows: `$NMO` (if executable) -> `PATH` -> `nix build .#nmo`.
