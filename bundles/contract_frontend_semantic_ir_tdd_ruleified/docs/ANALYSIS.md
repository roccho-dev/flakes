This executable bundle is the green implementation of the earlier specification-only extension.

Incorporated changes from review:
1. sa08 was too strong because it forced a proof-capable backend target even for exact artifact paths that already have an accepted non-proof exactness story, such as exact CUE leaves.
   The executable rule is now exact_only_clause_missing_exactness_anchor.
   Acceptable anchors are ExactnessAnchor, ProofBackendTarget, or EquivalenceBasis.

2. QualityBudget was too coarse.
   The executable fact inventory now separates LatencyBudget, CostBudget, AuthzContract, and ProductionTraceBinding.

3. fg12 previously overclaimed end-to-end trace completeness.
   The executable rule now imports GoalEventSource, UseCaseForTarget, and ClauseWitnessObligation, scopes the check through WholeSystemTarget, and requires whole-system target achievement to respect linked use-case achievement.

4. The TDD entry path previously regressed to Python.
   The executable harness is now shell-only again; bin/run_red.sh, bin/run_green.sh, and bin/run_red_green.sh call a shell runner directly.

Resulting executable scope:
- frontend semantic capture
- lowerable set semantics and backend capability matching
- whole-system trace completeness for explicitly scoped targets
- adequacy obligation completeness
- runtime and quality obligation completeness

5. Lowering presence requirements were still underspecified.
   The executable rules now fail red when a lowered clause omits ClauseBackend, ClauseLoweringMode, ClauseFeature, or ClauseArtifact.
   Whole-system targets also fail red if any lowered clause lacks ClauseArtifact, so artifact trace completeness is no longer only a documentation claim.
