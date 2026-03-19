# Recovery

Use recovery mode when collection does not produce execution-grade inputs.

## Failure Classes

### 1. No Reply

Symptoms:

- prompt was sent
- no usable answer returned

Response:

- check source approval
- tighten output contract
- resend once with a narrower prompt
- if still missing, mark blocked explicitly

### 2. Non-Structured Reply

Symptoms:

- reply exists
- required sections or tables are missing

Response:

- diagnose why the prompt underperformed
- require a table-only or section-locked format
- resend once
- if still weak, downgrade source quality and consider fallback source

### 3. Runtime Block

Symptoms:

- browser or transport path fails
- source cannot be reached

Response:

- make the blocker explicit in state
- switch to another approved runtime path if one exists
- do not hide the block under vague status

## Recovery Output

Recovery mode should return:

```text
RECOVERY_STATUS
SOURCE_RESULT_TABLE
IMPROVED_PROMPT_RESENDS_TABLE
REMAINING_BLOCKERS
```

If the scope is evidence-driven, also return partial evidence tables.

If the scope is design-driven, also return a merge table updated with the best
available objection or stress result.
