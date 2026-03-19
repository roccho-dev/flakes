# Tables

## Status Table

```text
member/url | goal | status
```

Use `member` as the logical path-like name.
Append runtime session or URL in the same column when needed.

Status should say what is missing, not only `incomplete`.

Examples:

- `prompt sent, no structured reply yet`
- `broad survey only, claim evidence missing`
- `good answer, not yet decision-grade`
- `merge missing strongest objection`

## Weakness Table

```text
member/url | goal | status
```

Use for weak or missing outputs only.

## Prompt Improvement Table

```text
member/url | diagnosis of weakness | prompt delta | stronger required format | resend priority
```

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
