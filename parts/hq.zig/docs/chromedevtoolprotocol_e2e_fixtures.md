# Chromedevtoolprotocol E2E Fixture Strategy

## Goal

Define a repeatable, low-risk set of sacrificial ChatGPT fixtures for proving HQ CDP workflows end to end.

The fixtures must be safe to mutate and easy to recognize in the ChatGPT UI.

## Chosen sacrificial project

- Project: `test`
- Project id: `69b22ee0b4908191b7644ddc47985da1-test`
- Project URL: `https://chatgpt.com/g/g-p-69b22ee0b4908191b7644ddc47985da1-test/project`

Rationale:

- The name already signals low-risk experimentation.
- It is present in current `project-inventory` output.
- It avoids mutating domain-specific projects like `datalog`, `nix/wit`, or `agent`.

## Thread fixture types

All sacrificial thread titles and markers must start with `HQ_E2E_`.

### 1. Unprojected seed thread

Used for:

- proving `projectize-thread`
- creating a fresh projected thread when project chats are empty

Naming:

- title marker: `HQ_E2E_PROJECTIZE_<ts>_<slug>`

### 2. Project writer thread

Used for:

- sending a markerized payload
- promoting a turn to Project Sources
- uploading files to a thread once `thread.file upload` exists

Naming:

- title marker: `HQ_E2E_WRITER_<ts>_<slug>`

### 3. Project reader thread

Used for:

- reading back a Project Source promoted from another thread
- verifying cross-thread visibility

Naming:

- title marker: `HQ_E2E_READER_<ts>_<slug>`

## Marker scheme

Each proof run uses a unique source marker:

- `SOURCE_ID: HQ_E2E_<workflow>_<ts>_<token>`

Required properties:

- ASCII only
- globally unique per run
- short enough to survive model/UI echo limits

Recommended fields:

- workflow: `projectize`, `promote`, `collect`, `download`, `upload`, `roundtrip`
- ts: UTC compact timestamp, e.g. `20260318T103500Z`
- token: short random hex, e.g. `a1b2c3`

## File fixtures

Store local proof files under:

- `/tmp/hq_e2e_fixtures/`

Recommended files:

- `HQ_E2E_NOTE_<ts>.txt`
- `HQ_E2E_PATCH_<ts>.diff`

Rules:

- tiny text payloads only
- deterministic content where possible
- include `SOURCE_ID:` marker on first line

## Proof sequencing

### Milestone A

- re-prove `project[] list/get`
- re-prove `project.thread[] list/get`

### Milestone B

- create one unprojected seed thread
- move it into `test`
- create / reuse writer + reader threads inside `test`
- prove turn promotion into Sources
- prove source lookup by marker
- prove file download from promoted source/turn

### Milestone C

- implement `thread.file upload`
- prove upload on writer thread
- prove full roundtrip: upload -> thread turn -> promote -> source lookup -> download

## Cleanup policy

- Prefer reusing existing `HQ_E2E_*` threads over creating many new ones.
- Never mutate non-`HQ_E2E_*` threads for E2E proofs.
- Keep source/file payloads minimal.
- If a proof leaves residue, document the residue rather than mutating unrelated chats.

## Evidence paths

Use stable temporary directories per workflow, for example:

- `/tmp/hq_project_inventory_recheck/`
- `/tmp/hq_e2e_projectize/`
- `/tmp/hq_e2e_promote/`
- `/tmp/hq_e2e_download/`
- `/tmp/hq_e2e_upload/`
- `/tmp/hq_e2e_roundtrip/`

Each E2E step should write:

- machine-readable JSON result
- optional Markdown summary
- copied/downloaded files when relevant
