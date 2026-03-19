# Examples

These are shape examples only. They are not fixed runtime assignments.

## Example Design Scope

```text
oc/<design-scope>
  -> oc/<design-scope>/gpt-design-lead
  -> oc/<design-scope>/gpt-dissent-boundary
  -> oc/<design-scope>/gpt-backend-stress
  -> oc/<design-scope>/gpt-reserve
```

Expected outputs:

- concrete options table
- objections table
- backend stress table
- merge table

## Example Evidence Scope

```text
oc/<evidence-scope>
  -> oc/<evidence-scope>/gpt-claim-<id>
  -> oc/<evidence-scope>/gpt-counter
  -> oc/<evidence-scope>/gpt-reference
```

Expected outputs:

- claim table
- evidence table
- decision impact table

## Example Progression

```text
source-selection
-> declaration-send-complete
-> response-collection
-> weakness-diagnosis
-> prompt-improvement
-> decision-grade-merge
-> implementation-lock
-> backend-execution
```

## Example Exit Logic

The overall system is not done until:

- one candidate path is selected
- lock-now vs defer is explicit
- main objections are recorded
- at least one backend path executes successfully
