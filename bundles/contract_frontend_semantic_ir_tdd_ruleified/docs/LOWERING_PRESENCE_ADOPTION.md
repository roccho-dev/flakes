# Lowering presence adoption

Accepted and ruleified from review:

- `ClauseBackend` is now mandatory for lowered clauses outside whole-system scope.
- `ClauseLoweringMode` is now mandatory for lowered clauses outside whole-system scope.
- `ClauseFeature` is now mandatory for lowered clauses outside whole-system scope.
- `ClauseArtifact` is now mandatory for lowered clauses outside whole-system scope.
- `WholeSystemTarget` now fails when any lowered clause lacks `ClauseArtifact`.

Added red cases:

- `ls16` `lowered_clause_missing_backend_identity`
- `ls17` `lowered_clause_missing_lowering_mode`
- `ls18` `lowered_clause_missing_feature_declaration`
- `ls19` `lowered_clause_missing_artifact_identity`
- `tr05` `whole_system_lowered_clause_missing_artifact_identity`

Execution result after adoption:

- red: 60 / 60 pass
- green: 12 / 12 pass
