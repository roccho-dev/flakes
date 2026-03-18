# Contract Frontend / Set IR / TDD Red Proposal

## Recommended split

1. Goal/Event Frontend
2. Semantic Contract IR
3. Lowerable Set IR
4. Backend Capability Matrix
5. Datalog cross-artifact verifier
6. Backend emitters (JSON Schema / CUE / SQL-like / Lean4)
7. Runtime / adequacy / quality suites

## Why this split

- The current canonical strict source IR is a strong lowerable core.
- It starts too late to fully own the responsibility of compiling from purpose/event frontend input.
- The missing layer is a frontend semantic IR that fixes population, event meaning, clock, quantifier domain, and ambiguity before backend lowering.

## Proposed red inventory

### contract_frontend_red_suite

- fe01 `frontend_root_missing_actor_scope`
- fe02 `frontend_root_missing_population_definition`
- fe03 `frontend_goal_missing_event_anchor`
- fe04 `frontend_goal_missing_time_source`
- fe05 `frontend_goal_missing_observation_window_anchor`
- fe06 `frontend_objective_guardrail_collision`
- fe07 `frontend_assumption_compiled_as_fact`
- fe08 `frontend_constraint_compiled_as_objective`
- fe09 `frontend_quantifier_domain_missing`
- fe10 `frontend_event_identity_missing`
- fe11 `frontend_join_key_missing`
- fe12 `frontend_aggregation_subject_ambiguous`
- fe13 `frontend_unknown_null_policy_missing`
- fe14 `frontend_closed_world_policy_missing`
- fe15 `frontend_metric_not_reducible_to_event_semantics`
- fe16 `frontend_leaf_stop_without_measurement_reason`
- fe17 `frontend_compile_trace_missing`
- fe18 `frontend_compile_loss_unmarked`

### set_ir_lowering_red_suite

- ls01 `set_clause_missing_quantifier_kind`
- ls02 `set_clause_missing_domain_scope`
- ls03 `set_clause_missing_grouping_key_when_aggregated`
- ls04 `set_clause_missing_clock_binding`
- ls05 `set_clause_conflicting_window_semantics`
- ls06 `backend_capability_missing`
- ls07 `backend_capability_mismatch`
- ls08 `exact_lowering_without_equivalence_basis`
- ls09 `approximate_lowering_without_soundness_direction`
- ls10 `backend_specific_grammar_leaked_to_canonical_ir`
- ls11 `single_instance_backend_claims_dataset_semantics`
- ls12 `artifact_cover_missing_for_lowered_clause`
- ls13 `artifact_identity_conflict`
- ls14 `lowering_trace_missing_source_clause`
- ls15 `mixed_backend_root_missing_soundness_policy`
- ls16 `lowered_clause_missing_backend_identity`
- ls17 `lowered_clause_missing_lowering_mode`
- ls18 `lowered_clause_missing_feature_declaration`
- ls19 `lowered_clause_missing_artifact_identity`

### proof_and_semantic_adequacy_adjacent_suite

- sa01 `necessity_claim_missing_ablation_case`
- sa02 `sufficiency_claim_missing_counterexample_case`
- sa03 `complete_or_branch_missing_gap_scan`
- sa04 `assumption_missing_break_case`
- sa05 `hidden_dependency_missing_declaration`
- sa06 `tradeoff_goal_missing_conflict_clause`
- sa07 `approximation_claim_missing_proof_anchor`
- sa08 `exact_only_clause_missing_exactness_anchor`

### contract_system_trace_suite

- tr01 `whole_system_target_missing_goal_event_source`
- tr02 `whole_system_target_missing_usecase_link`
- tr03 `whole_system_exact_clause_missing_witness_obligation`
- tr04 `whole_system_target_blocked_by_linked_usecase_violation`
- tr05 `whole_system_lowered_clause_missing_artifact_identity`

### runtime_quality_obligation_suite

- rq01 `runtime_timeout_test_missing`
- rq02 `runtime_retry_test_missing`
- rq03 `runtime_duplicate_event_test_missing`
- rq04 `runtime_reorder_test_missing`
- rq05 `runtime_staleness_test_missing`
- rq06 `runtime_counterexample_replay_missing`
- rq07 `usecase_latency_budget_missing`
- rq08 `usecase_cost_budget_missing`
- rq09 `usecase_authz_contract_missing`
- rq10 `production_trace_binding_missing`

## Priority

### Wave 1
- fe01-fe18
- ls06-ls10
- ls14-ls19

### Wave 2
- ls01-ls05
- ls11-ls13
- tr01-tr05
- sa07-sa08

### Wave 3
- sa01-sa06
- rq01-rq10

## Minimal message

Before adding more backends, make the frontend compile semantics explicit and make every semantic loss, unsupported exactness claim, and missing obligation fail red.
