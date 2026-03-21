# Runbook

Use this file when resuming or actively operating a live discussion-management
run.

This runbook is procedural. It tells the operator what runtime state must exist
 and how it must be updated.

## First Rule

Every operational update must be table-first.

At minimum, every progress update must include:

```text
member/url | goal | status
```

Write those columns this way:

- `goal`: declarative end-state; describe what must be true when the member is
  done
- `status`: declarative current state relative to that goal; describe what is
  already true, what is still missing, or what blocker exists
- keep instructions, resend steps, and next moves out of `goal` and `status`

Do not respond with free prose only.
Use prose only after the state tables.

When a run depends on high-quality downstream `gpt` outputs, read
`references/gpt_request_contracts.md` before sending or repairing prompts.

When principle-level interpretation matters, read
`references/principles/index.md`.

When lane boundaries matter, read the relevant file under `lanes/` before
continuing.

## Next Entry Point

- Read `references/principles/index.md`.

## Delegation Rule

Default operating bias is GPT-heavy.

- prefer letting approved `gpt` sources do the content work
- keep `oc` focused on control-plane work
- treat a strong bias such as `~90% delegation` as an operating preference, not
  as a precise metric

Content work that should stay in `gpt` whenever possible includes:

- table reconstruction
- structured restatement
- objection generation
- option comparison
- evidence restatement
- required-format regeneration

`oc` should retain:

- approved source control
- output contract enforcement
- weakness diagnosis
- resend policy
- merge and decision-state control
- lock/defer judgment
- execution verification

## Access Rule

In this runbook, `spec` means the current managing operator/session running the
discussion system.

Access from `oc` to approved `gpt` sources should follow these rules:

- prefer send-once and one-shot collection
- do not poll by default
- polling is allowed only when the current run has explicit approval for it
- when waiting is needed, wait and do a later one-shot check instead of a loop
- record runtime or transport blockers explicitly in state
- if repeated access was used under an approved exception, make that exception
  explicit in the update
- treat downstream `gpt` state as known only after `oc` has recovered and
  reported it
- do not fill per-`gpt` state rows from operator inference alone
- when per-source content matters, materialize a source report table instead of
  returning merge-only reporting

## Re-entry Rule

If memory is missing, reconstruct runtime state before doing anything else.

The minimum runtime state to reconstruct is:

1. overall objective
2. approved members and sources
3. current `member/url | goal | status`
4. weak or blocked members
5. next required transitions

## Required Runtime State

On every active run, maintain these runtime tables.

When delegation strategy matters, also materialize a delegation policy registry.

### 1. Main State Table

```text
member/url | goal | status
```

This is the mandatory organization/state view.

`goal` is not a how-to field.
`status` is not a vague phase label.

Prefer state descriptions such as:

- `strong dissent table is recovered and merge-ready`
- `recommended option is explicit; rejected options are not yet explicit`
- `backend artifact is generated; test result is missing`

### 2. Approved Sources Table

```text
member/url | role | approved | evidence/state
```

### 3. Weakness Table

```text
member/url | goal | status
```

Use this only for weak, missing, blocked, or non-decision-grade outputs.

### 4. Prompt Improvement Table

```text
member/url | diagnosis of weakness | prompt delta | stronger required format | resend priority
```

### 5. Next Action Table

```text
member/url | next required transition | blocker | owner
```

### 6. Source Report Table

```text
member/url | what the GPT reported | how it is being used | confidence/limitation
```

Use this when `oc` reports downstream `gpt` outputs back to `spec` and the
per-source content matters for management or decision-state.

Only report recovered source content here.
Do not fill this table from inference or guesswork.

## If State Does Not Yet Exist

If the state table is missing, create it immediately.

State creation must:

1. define the whole objective
2. decompose it into scoped subsets
3. assign each subset to a logical member
4. attach approved session/url values where available
5. write each member goal as an end-state
6. mark current status of each member as a declarative current state

## Operational Loop

Run the discussion system in this order:

1. update the main state table
2. confirm approved sources
3. identify weak or blocked members
4. diagnose prompt weakness if needed
5. resend only through approved sources
6. update collection state
7. update decision state
8. update execution state

Each loop must end with an updated table set.

During this loop, do not pull content work back into `oc` unless:

- no approved `gpt` source can do it
- the work is control-plane only
- execution verification requires direct operator action

During this loop, do not turn `oc -> gpt` access into background polling unless
an explicit exception was approved for the run.

During this loop, do not promote downstream `gpt` state into `spec` state until
`oc` has reported that state in recovered form.

## Completion Rules

### Collection complete

Collection is complete only when expected structured outputs have been recovered
from the required approved sources.

### Decision complete

Decision is complete only when:

- one recommended option exists
- strongest objection is explicit
- rejected or deferred options are explicit
- cheapest next test is explicit

### Execution complete

Execution is complete only when at least one backend path has actually run.

## Source Control Rule

Do not add new sources silently.

If a new source is needed:

1. add `UNAPPROVED_SOURCE_REQUEST`
2. explain why existing approved sources are insufficient
3. do not use the new source until approved

## Failure Conditions

Treat these as failures:

- no updated state table
- prose-only progress reporting
- `goal` written as an instruction instead of an end-state
- `status` written as a vague label instead of a verified state
- unnecessary `oc`-side recreation of content that should have been produced by
  an approved `gpt` source
- unapproved polling or repeated checking against `gpt` sources
- per-`gpt` state reported without recovered `oc` evidence
- merge-only reporting when per-source source content materially affects the
  decision
- weak reply with no diagnosis
- resend with no prompt delta
- use of unapproved source
- no path toward decision or execution

## Minimal Resume Procedure

When resuming a run, do this in order:

1. read `SKILL.md`
2. read this file
3. reconstruct or read current runtime state
4. emit the current `member/url | goal | status` table
5. identify the top blocker
6. continue from the next required transition

## Output Contract For Ongoing Management

Every management update should prefer this shape:

```text
member/url | goal | status
member/url | goal | status
...

member/url | what the GPT reported | how it is being used | confidence/limitation
...

member/url | diagnosis of weakness | prompt delta | stronger required format | resend priority
...

member/url | next required transition | blocker | owner
...
```

This is the minimum reusable form for carrying the run forward after memory loss.
