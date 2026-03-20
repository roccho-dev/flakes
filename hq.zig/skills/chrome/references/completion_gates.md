# Completion Gates

Use this file when a Chrome/CDP recovery run needs explicit pass/fail states
instead of vague labels such as "started", "looks good", or "probably fine".

The main purpose of this file is to separate states that are often conflated in
practice:

- process alive
- CDP reachable
- page attachable
- login/challenge state
- composer readiness
- attachment readiness
- end-to-end consult route readiness

## Fine-Grained Completion States

| Area | Completion state that should be declared | Why it is distinct |
|---|---|---|
| Launch | `Chrome process is detached and still alive after a one-shot delay check.` | "started" and "survives" are different states |
| Browser CDP | `Browser-level CDP is healthy: either /json/version responds or browser websocket accepts a session.` | A live process can still expose a broken control plane |
| Page target | `At least one ChatGPT page target exists and is attachable.` | Browser CDP health does not guarantee a usable page target |
| Saved profile reuse | `Saved profile is reusable only if browser CDP stays healthy and a ChatGPT page target can be attached without GUI recovery.` | Profile presence is not the same as profile usability |
| Fresh profile baseline | `Fresh profile is usable when GUI or headless Chrome stays up, CDP is healthy, and ChatGPT home can be opened.` | Fresh profile is the diagnostic baseline, not just an empty directory |
| Login state | `The page is exactly one of: logged-in, login-required, challenge-blocked.` | Login and challenge must not be collapsed into one blocker |
| GUI recovery | `GUI recovery is complete only when Xvfb, Chrome, and optional VNC are each in their intended state.` | Partial GUI recovery creates false confidence |
| VNC recovery | `VNC recovery is complete only when x11vnc is alive and the VNC listener is open.` | A live X display without usable remote access may still be insufficient |
| Composer ready | `Composer-ready means prompt surface exists and send path is interactable.` | Page open is not the same as send-ready |
| Attachment ready | `Attachment-ready means file input or filechooser path is available and can accept a file.` | Text send and file send are separate recovery paths |
| Consultation route | `Consult route is healthy only when qjs + bridge + target selection + send/read path all work together.` | Component-level health does not imply end-to-end success |
| Recovery exit | `Recovery mode exits when one-shot send/read/attach succeeds; polling does not resume by default.` | Recovery needs a clear end condition |
| GPT runtime claim | `A GPT runtime claim is accepted only after it is explicitly labeled as runtime-confirmed or static-inference.` | Prevents self-reports from becoming silent truth |
| Artifact lineage | `Patch-producing work is complete only if diff and latest snapshot are recoverable, or Git lineage is explicit.` | Handoff without artifacts is not execution-grade |

## Saved-Profile Decision Gate

| Condition | Decision |
|---|---|
| Process dies quickly even after detached launch | treat as launch/runtime failure first |
| Process survives but CDP is unstable or hangs | do not call the saved profile reusable yet |
| Browser CDP is healthy but page state is login/challenge blocked | saved profile may still be acceptable, but only for GUI recovery |
| Browser CDP is healthy and page target is attachable without GUI recovery | saved profile is reusable |

## Fresh-Profile Recovery Gate

| Condition | Decision |
|---|---|
| Fresh profile + detached launch is stable | use fresh profile as the baseline recovery path |
| Fresh profile + GUI is stable but headless is not | keep GUI recovery and do not force headless |
| Fresh profile fails the same way as saved profile | the issue is probably not profile-specific |

## GUI/VNC Gate

| Subsystem | Good state | Bad state |
|---|---|---|
| Xvfb | process alive and X socket exists | process gone or no X socket |
| x11vnc | process alive and `:5900` listener exists | auth/path issue, no listener |
| Chrome | process alive and browser websocket or `/json/version` responds | process alive but no usable control plane, or immediate exit |
| ChatGPT page | home or thread page opens and page can be attached | browser open but no usable page target |

## Consultation Route Gate

| Stage | Good state |
|---|---|
| Transport | `cdp-bridge` (or replacement bridge) answers the required low-level requests |
| Targeting | `qjs` can identify or open the intended page/thread target |
| Send | text send path works |
| Attach | file input or filechooser path works |
| Read | latest assistant output can be collected in one-shot mode |

The consult route is not complete until all stages above are satisfied for the
current run.

## Ownership Gate

| Function | Primary owner | Secondary / notes |
|---|---|---|
| Dynamic DOM and UI choreography | `qjs` | Keep the moving parts in scripts |
| Durable app state and SQLite | `hq.zig` | Keep long-lived state out of DOM scripts |
| Reusable Zig CDP primitives | `chromedevtoolprotocol.zig` | Stable dependency layer |
| Low-level bridge transport | `cdp-bridge.zig` | Transitional glue, not final visible owner |

## Reporting Rule

When reporting recovery progress, prefer statements such as:

- `Chrome process is alive; browser CDP is not yet healthy`
- `Browser CDP is healthy; page target is attachable; login is still required`
- `GUI stack is healthy; VNC is not yet healthy`
- `Saved profile is present but not yet reusable`
- `Fresh profile GUI route is healthy enough for manual login`
- `Consult route is healthy for text send but not yet for attachments`

Avoid compressed statements such as:

- `Chrome works`
- `profile is good`
- `CDP is up`
- `login failed`

unless the underlying gate is already explicit.
