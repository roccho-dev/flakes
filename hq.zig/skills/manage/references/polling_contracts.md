# Polling Contracts

Use this file when a run needs repeated checks against downstream `gpt` or
transport state and one-shot collection is insufficient.

Polling is not the default.
It is an explicitly approved exception with bounded behavior.

## Default Rule

- prefer send-once and one-shot collection
- do not poll by default
- only poll when the current run has explicit approval

## Account-Safe Polling

When polling is approved, it must be account-safe.

That means every polling run declares all of the following:

- target scope
- success condition
- interval range
- jitter policy
- maximum tries and/or maximum duration
- immediate stop conditions
- reporting contract

## Required Fields

```text
POLL_SCOPE
POLL_SUCCESS_CONDITION
POLL_INTERVAL
POLL_JITTER
POLL_CAP
POLL_STOP_CONDITIONS
POLL_REPORT_CONTRACT
```

Good examples:

- `POLL_SCOPE = GPT thread reply completion`
- `POLL_SUCCESS_CONDITION = stop=false and hasPrompt=true`
- `POLL_INTERVAL = 5-15 seconds`
- `POLL_JITTER = random per iteration`
- `POLL_CAP = max 8 tries or max 5 minutes`

## Immediate Stop Conditions

At minimum, stop immediately on:

- Cloudflare challenge or equivalent interstitial
- login-required state
- rate-limit or quota symptoms
- session lost or target not found
- unexpected tab drift
- authentication mismatch

These are burden guards, not just runtime errors.

## Reporting Contract

Every approved polling run should return:

```text
POLL_RESULT
LAST_OBSERVED_STATE
STOP_REASON_OR_SUCCESS
```

If artifact readiness is the target, also return:

```text
ANY_NEW_ARTIFACTS
```

## Store/Observer Streams

If a stream is acting as observer/store only, say so explicitly.

For example:

- `observer-only; no sends performed`

Observer/store streams should:

- observe state
- detect recoverable artifacts
- avoid content-side interventions
- report what changed

## Hard Rules

- Do not convert "no visible progress yet" into immediate failure after one sleep.
- Do not continue polling beyond the approved cap.
- Do not hide challenge/login/rate-limit conditions.
- Do not use polling as a substitute for missing source contracts.

## Recommended Prompt Fragment

```text
This run explicitly approves account-safe polling.
Target: <scope>
Success condition: <condition>
Use <min>-<max> second random sleep with jitter.
Cap: <tries/time>.
Stop immediately on Cloudflare, login, rate-limit, session loss, or tab drift.
Return: POLL_RESULT, LAST_OBSERVED_STATE, STOP_REASON_OR_SUCCESS.
```

## Next Entry Point

- Read `target_session_contracts.md`.
