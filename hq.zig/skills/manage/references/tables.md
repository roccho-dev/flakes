# Tables

## Status Table

```text
member/url | goal | status
```

Use `member` as the logical path-like name.
Append runtime session or URL in the same column when needed.

Write the columns this way:

- `goal`: declarative end-state; describe what must be true when the member is
  done
- `status`: declarative current state relative to that goal; describe what is
  already true, what is missing, or what blocker exists

Do not use `goal` for instructions such as `resend`, `collect`, `check`, or
`decide`.
Do not use `status` as a vague label such as `incomplete` or `in progress`
without saying what is actually present or missing.

Keep next moves in the next-action table, not in the status table.

Examples:

- goal: `strong dissent table is recovered and merge-ready`
- status: `structured dissent reply is recovered; merge table is missing`
- goal: `recommended option is implementation-locked`
- status: `recommended option and strongest objection are explicit; rejected options are not yet explicit`
- goal: `backend path has executed and produced test results`
- status: `artifact is generated; execution result is missing`

## Weakness Table

```text
member/url | goal | status
```

Use for weak or missing outputs only.
Keep the same declarative writing rule for `goal` and `status`.

## Prompt Improvement Table

```text
member/url | diagnosis of weakness | prompt delta | stronger required format | resend priority
```

## Source Report Table

```text
member/url | what the GPT reported | how it is being used | confidence/limitation
```

Use this when `oc` reports downstream `gpt` outputs back to `spec` and the
source-by-source content matters.

Rules:

- include only recovered source content
- do not fill this table from inference, reconstruction, or operator guesswork
- do not let this replace the merge table; use it as the readable per-source
  bridge

## Merge Table

```text
member/url | role | contribution | strongest usable output | weakness | impact on decision
```

## Claim Table

```text
claim | why it matters | lock target | fallback if weak | current status
```

## Evidence Table

```text
claim | member/url | role | supports what | does NOT support | limitation/counter | implementation impact
```

## Decision Impact Table

```text
claim | evidence status | can lock now? | cheapest next test | owner
```

## Next Entry Point

- Read `recovery.md`.
