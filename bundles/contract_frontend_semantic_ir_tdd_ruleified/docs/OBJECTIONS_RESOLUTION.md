# Objections resolution

This bundle fully accepts the two review objections and applies executable fixes.

## 1. fg12 trace overclaim

Accepted.

Applied fix:
- imported `GoalEventSource`, `UseCaseForTarget`, and `ClauseWitnessObligation`
- added `WholeSystemTarget` to scope whole-system trace checking explicitly
- made whole-system target achievement depend on linked use-case cleanliness
- added red cases `tr01`..`tr04` to prevent regression

## 2. Python harness regression

Accepted.

Applied fix:
- removed the Python-dependent entry path from `bin/run_red.sh`, `bin/run_green.sh`, and `bin/run_red_green.sh`
- restored a shell-only runner via `bin/_run_suite.sh`
- removed the `python3` requirement from user-facing docs

## Result

- red: 60 / 60 pass
- green: 12 / 12 pass
- entry path: shell-only

## 3. Lowering presence gaps

Accepted.

Applied fix:
- added executable red rules for `ClauseBackend`, `ClauseLoweringMode`, `ClauseFeature`, and `ClauseArtifact` presence on lowered clauses
- added whole-system red rule for missing clause artifact identity on lowered clauses
- added red cases `ls16`..`ls19` and `tr05` to prevent regression
