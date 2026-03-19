# Registries

Runtime data belongs in registries, not in `SKILL.md`.

## Objective Registry

```text
objective_id
objective_text
non_goals
success_criteria
open_questions
```

## Member Registry

```text
member
kind
role
goal
scope
owner
approved
```

- `kind`: `spec | oc | gpt`
- `role`: runtime-scoped, for example `design-lead`, `claim-evidence`, `dissent-boundary`

## Source Registry

```text
member
session_or_url
source_status
approval_state
evidence_refs
notes
```

## State Registry

```text
member
completion_state
decision_state
execution_state
blocking_issue
next_required_transition
```

## Prompt Contract Registry

```text
member
prompt_purpose
required_output_sections
quality_gates
resend_policy
```

## Delegation Policy Registry

Optional but recommended when delegation strategy matters.

```text
member
delegation_bias
target_share
delegate_to
keep_in_oc
notes
```

- `delegation_bias`: for example `gpt-heavy`
- `target_share`: optional operating preference such as `0.9`
- `delegate_to`: content work that should stay in `gpt` when possible
- `keep_in_oc`: control-plane work that must stay in `oc`

## Rule

`SKILL.md` defines the structure of these registries.
The registries carry live values.
