# Target Session Contracts

Use this file when a specific target session must be driven toward a stable role
in the `spec -> oc -> gpt` workflow.

## Three Required Properties

A target session contract is strong only when all three of these are true.

| id | property | meaning |
|---|---|---|
| T1 | role and done condition are explicit | the session knows what it owns and what counts as done |
| T2 | artifacts and handoff are recoverable | downstream actors can actually obtain the outputs |
| T3 | access behavior is controlled | polling/rechecks follow an approved bounded contract |

## T1. Role and Done Condition

Every target session should be told:

- what role it plays
- what it does not own
- what counts as progress
- what counts as done

Examples:

- `you are the upstream patch/artifact stream`
- `you are the downstream local confirm stream`
- `done means downstream local green`

## T2. Recoverable Artifacts and Handoff

If the target session is expected to produce actionable outputs, require:

- downloadable diff or patch artifact
- downloadable latest snapshot or equivalent recovery artifact
- explicit handoff contract for the next actor

Recommended fields:

```text
FINAL_HANDOFF_PACKAGE
ATTACHED_FINAL_DIFF
ATTACHED_FINAL_SERIES
ATTACHED_FINAL_SNAPSHOT
WHAT_DOWNSTREAM_SHOULD_RUN_FIRST
```

## T3. Controlled Access

If the target session must be checked repeatedly, do not rely on ad hoc waiting.

Require either:

- one-shot collection, or
- approved bounded polling using `polling_contracts.md`

## Role Templates

### Upstream GPT Session

Required declarations:

- `STREAM_ROLE_UNDERSTOOD`
- `SELF_CHECKED_SCOPE`
- `NOT_YET_DOWNSTREAM_CONFIRMED`
- `WHAT_DOWNSTREAM_MUST_CONFIRM`
- `DONE_CONDITION_UNDERSTOOD`

### Downstream OC Session

Required declarations:

- `STREAM_ROLE_UNDERSTOOD`
- `UPSTREAM_ARTIFACT_ACCEPTED_AS_INPUT`
- `LOCAL_CONFIRMED_NOW`
- `FIRST_FAILING_OR_GREEN`
- `GATE_DECISION`
- `DONE_CONDITION_UNDERSTOOD`

### Store / Observer Session

Required declarations:

- `STREAM_ROLE_UNDERSTOOD`
- `POLLING_POLICY_UNDERSTOOD`
- `LAST_OBSERVED_STATE`
- `POLL_RESULT`
- `ANY_NEW_ARTIFACTS`
- `STOP_REASON_OR_SUCCESS`

## Session Discovery Rule

When exact target-session identity matters, prefer live service discovery over
guessing from stale local state.

Do not assume:

- title aliases
- slug aliases
- local-only session names

If exact target identity is required, verify it from the active service/session
surface first.

## Next Entry Point

- Read `downstream_local_confirm_contracts.md`.
