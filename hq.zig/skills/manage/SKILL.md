# Discussion Management Skill

## Goal

This skill captures how `spec` manages a multi-layer discussion system:

- `spec` owns the full objective
- `oc` sessions are delegated managers
- GPT threads are external sources

The management goal is not only to collect advice. It is to drive the whole flow
from:

- purpose clarification
- IR design closure
- claim-based evidence collection
- dissent and counterargument capture
- backend decision
- backend execution

through to a state where one implementation path is chosen and at least one
backend actually works.

## Core Model

```text
spec
  -> oc
    -> gpt
```

- `spec`
  - decision owner
  - integration owner
  - execution owner
- `oc`
  - scoped manager for one concern area
  - tracks completion-state, decision-state, and execution-state
- `gpt`
  - external source of designs, objections, theory, comparisons, and stress tests
  - never treated as source of truth by itself

## Naming And Tracking Convention

Status rows must use this schema:

```json
["member/url", "goal", "status"]
```

Interpretation:

- `member`
  - the old path-like logical member name
  - examples: `oc/oc-ir`, `oc/oc-paper/gpt-D2`
- `url`
  - either the session name or the concrete GPT URL
  - keep it in the same column as `member`

Recommended rendering:

```text
member/url | goal | status
```

Examples:

```text
spec | IR design complete + backend working | decision incomplete, execution incomplete
oc/oc-ir | converge to one IR candidate | waiting for decision-grade merge table
oc/oc-ir/gpt-design-lead / https://chatgpt.com/c/... | 2-3 concrete IR options | prompt sent, table not yet collected
```

## What `spec` Is Responsible For

`spec` is responsible for all of the following, not only message routing:

1. Keep the large purpose explicit
2. Split work into the right `oc` managers
3. Prevent scope drift
4. Prevent unapproved GPT source sprawl
5. Require dissent, not only agreement
6. Require claim-based evidence, not only broad survey
7. Require decision-grade outputs, not only suggestion-grade outputs
8. Choose one candidate when enough evidence exists
9. Decide what is locked now vs deferred to PoC
10. Drive at least one backend to real execution

## What `oc` Sessions Are Expected To Do

Each `oc` session should manage a bounded concern area and expose:

- what completion means
- what decision means
- what execution means
- which GPT sources are approved
- what is still missing
- which prompts underperformed
- how those prompts should be improved

An `oc` session should not silently invent new source threads. It must either:

- stay within the approved source set
- or raise `UNAPPROVED_SOURCE_REQUEST`

## Required Management Expectations

The following expectations should be treated as mandatory across the full
`spec -> oc -> gpt` system.

### 1. Objective Control

- The top-level objective is explicit and stable
- Subgoals are tracked under that objective
- Non-goals are explicit
- Open questions are explicit

### 2. Scope Separation

- IR design work is separated from evidence gathering work
- Broad survey is not allowed to swallow claim-driven work
- Backend stress is separated from semantic design
- Dissent is separated from design-lead output

### 3. Source Control

- Every GPT source is approved before use
- Every merged result records `member/url`
- New source creation is exceptional and explicit
- Reuse is preferred over uncontrolled source growth

### 4. Completion-State Control

- Every `oc` defines a completion-state
- Completion-state must depend on concrete evidence
- Completion-state is not satisfied by vague prose
- Completion-state must be checkable from the session itself

### 5. Decision-State Control

- Every `oc` must eventually expose a decision-state, not only a collection state
- Decision-state must show:
  - recommended option
  - rejected or not-yet options
  - strongest objection
  - remaining open question
  - cheapest next test

### 6. Execution-State Control

- At least one path must move from discussion into execution
- Backend execution is not optional forever
- A chosen path must lead to a real artifact or test

### 7. Dissent Capture

- At least one source must be dedicated to objections
- Weak objections are not enough
- Required objection classes include:
  - framing objections
  - ontology objections
  - backend-bias objections
  - minimum-correction proposals

### 8. Evidence Discipline

- Broad survey alone is insufficient
- Evidence must be claim-based where implementation lock depends on it
- Each claim should ideally have:
  - support
  - counter or limitation
  - design implication
  - implementation impact

### 9. Prompt Quality Management

- Weak or missing responses must trigger prompt diagnosis
- `oc` should explain why the prompt underperformed
- `oc` should propose a prompt delta, not only note failure
- Prompt improvements should be ranked by resend priority

### 10. Decision-Grade Output Preference

GPT output is stronger when it includes fields like:

- `RECOMMENDED_OPTION`
- `WHY_THIS_SHOULD_BE_CHOSEN`
- `WHY_OTHER_OPTIONS_SHOULD_NOT_BE_CHOSEN_YET`
- `STRONGEST_OBJECTION`
- `DISCONFIRMING_EVIDENCE`
- `CHEAPEST_NEXT_TEST`

Management should push sources toward this level whenever possible.

## Recommended `oc` Split

### `oc/oc-ir`

Purpose:

- converge post-IR design into one candidate handoff model

Recommended child members:

```text
oc/oc-ir/gpt-design-lead
oc/oc-ir/gpt-dissent-boundary
oc/oc-ir/gpt-backend-stress
oc/oc-ir/gpt-reserve
```

Expected outputs:

- concrete IR options table
- objections table
- backend stress table
- merge table

### `oc/oc-paper`

Purpose:

- gather implementation-lock evidence by claim

Recommended child members:

```text
oc/oc-paper/gpt-D1
oc/oc-paper/gpt-D2
oc/oc-paper/gpt-D3
oc/oc-paper/gpt-D4
oc/oc-paper/gpt-D5
oc/oc-paper/gpt-counter
oc/oc-paper/gpt-reference
```

Where claims typically mean:

- `D1`: purpose -> operationalization
- `D2`: semantic-core semantics
- `D3`: Nemo audit overlay
- `D4`: residual / proof / external checker
- `D5`: multi-backend projection theory

Expected outputs:

- claim table
- evidence table
- decision impact table

## Required Tables

### Status Table

```text
member/url | goal | status
```

### Weakness Table

```text
member/url | goal | status
```

Status should say what is missing, not only "incomplete".

Examples:

- `prompt sent, no table response yet`
- `good answer but not decision-grade`
- `broad survey only, claim evidence missing`
- `backend stress done, merge not done`

### Prompt Improvement Table

Recommended columns:

```text
member/url | diagnosis of weakness | prompt delta | stronger required format | resend priority
```

## Quality Expectations For Returned Content

### Good IR-side answers should show

- 2-3 concrete options
- explicit recommendation
- explicit rejection or deferral
- explicit objections
- explicit residual handling
- backend stress view

### Good paper-side answers should show

- claim alignment
- source support
- source limitation or counterargument
- design implication
- implementation impact
- whether lock is justified now

## What Counts As Progress

Progress is not only "more discussion".
Progress means movement across these stages:

1. source selection
2. declaration-send completion
3. response collection
4. weakness diagnosis
5. prompt improvement
6. decision-grade merge
7. implementation lock
8. backend execution

## What Counts As Failure

The system is failing if any of these happen:

- too many uncontrolled GPT sources appear
- everyone agrees but nobody objects
- broad survey replaces claim-based evidence
- many suggestions exist but no recommendation is chosen
- IR stays abstract and never reaches backend execution
- weak answers are noted but prompts are not improved
- status tables stop reflecting real session state

## Minimal Exit Criteria

The overall management task is not done until:

- one IR / handoff candidate is selected
- the claim table says what is locked now vs deferred
- at least one backend path is executed successfully
- the main objections and residual risks are recorded

## Practical Operating Rule

When in doubt:

- tighten source control
- tighten output contracts
- ask for objections
- ask for decision-grade output
- ask for cheapest next test
- prefer one working backend over endless abstract refinement
