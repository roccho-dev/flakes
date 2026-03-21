# Required Inputs

Status: missing

## Meaning

If downstream work depends on specific source, environment, runtime, or artifact
context, that context should be declared at the start rather than dripped in later.

## Rules

- declare required source artifacts up front
- declare required runtime/toolchain versions up front
- declare intended platform/architecture when relevant
- say what counts as sufficient environment vs insufficient environment

## Completion Target

Downstream requests should not depend on hidden or late-arriving runtime context.

## Next Entry Point

- Read `source-governance.md`.
