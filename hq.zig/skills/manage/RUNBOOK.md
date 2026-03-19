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

Do not respond with free prose only.
Use prose only after the state tables.

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

### 1. Main State Table

```text
member/url | goal | status
```

This is the mandatory organization/state view.

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

## If State Does Not Yet Exist

If the state table is missing, create it immediately.

State creation must:

1. define the whole objective
2. decompose it into scoped subsets
3. assign each subset to a logical member
4. attach approved session/url values where available
5. mark current status of each member

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

member/url | diagnosis of weakness | prompt delta | stronger required format | resend priority
...

member/url | next required transition | blocker | owner
...
```

This is the minimum reusable form for carrying the run forward after memory loss.
