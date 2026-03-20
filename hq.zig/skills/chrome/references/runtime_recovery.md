# Runtime Recovery

This document records the practical Chrome/CDP findings needed by the next
operator who hits the same automation wall.

## Background Facts

| Area | Fact | Why It Matters |
|---|---|---|
| Access discipline | One-shot checks are preferred over polling | This matches the broader skill discipline and avoids turning runtime uncertainty into background churn |
| `qjs` | Best for dynamic DOM, selectors, retries, UI choreography | The ChatGPT UI changes often and benefits from fast script-side adjustment |
| `hq.zig` | Best for long-lived app logic, queue, batch, SQLite | Durable state belongs in Zig, not in DOM scripts |
| `cdp-bridge.zig` | Low-level CLI bridge for CDP HTTP/WS/filechooser | It is transport glue, not the app core |
| `chromedevtoolprotocol.zig` | Reusable Zig CDP library | This is the durable dependency layer |
| Current desired visible shape | `qjs + hq.zig` | `cdp-bridge.zig` is an acceptable temporary bridge, not the final desired surface |

## Current Component Split

| Feature | Current component | New/desired component | Background |
|---|---|---|---|
| Dynamic DOM search/click/input | `*.mjs` | `qjs` | Fast-moving UI belongs in scripts |
| ChatGPT operational orchestration | `*.mjs` | `qjs` | Send/read/attach/project flows are operational rather than durable app logic |
| Durable state, queue, batch, SQLite | `hq.zig` | `hq.zig` | Long-lived app state should stay in Zig |
| Reusable Zig CDP primitives | `chromedevtoolprotocol.zig` | `chromedevtoolprotocol.zig` | This is already the right layer |
| Low-level CDP bridge | `cdp-bridge.zig` | temporary bridge; eventually less visible | Needed today because `qjs` does not carry all transport logic directly |
| `qjs -> sqlite` direct writes | none | avoid | Prefer `qjs -> hq.zig -> sqlite` instead of teaching SQL/schema to `qjs` |

## Confirmed Findings

| Observation | Result | Meaning |
|---|---|---|
| Plain background launch with `&` | Unreliable | Do not trust it for Chrome persistence |
| Detached launch (`nohup`/equivalent) | Better | Launch method matters materially |
| Saved profile + headless | Can become unstable | The profile may be the problem, not the port |
| Fresh profile + headless | More stable | Best for isolating whether the profile is the blocker |
| Fresh profile + GUI | Stable enough for manual login and thread recovery | This is the safest fallback for recovery work |
| Saved profile + GUI | Process can persist, but CDP HTTP may still be flaky | GUI can help, but does not guarantee a healthy CDP control plane |
| File attachment | Possible via direct file input / filechooser | Do not assume the high-level send helper is the only path |

## Branching Recovery Table

| Step | Condition | Action | Why |
|---|---|---|---|
| 1 | Chrome seems to launch but disappears | Check whether the process actually survives detached launch | Process persistence must be established before any CDP diagnosis |
| 2 | Plain launch was used | Relaunch detached (`nohup`/equivalent) | Plain shell backgrounding is not trustworthy here |
| 3 | Detached launch still fails | Compare saved profile vs fresh profile | This separates profile corruption from transport problems |
| 4 | Fresh profile works, saved profile fails | Treat saved profile as suspect | Do not waste time blaming `9222/9223` first |
| 5 | Login/challenge recovery is needed | Use GUI (`Xvfb` + `x11vnc`) | Headful recovery is often easier than trying to automate through challenge state |
| 6 | GUI shows login instead of challenge | Login manually | This is not a Cloudflare issue; it is just auth state |
| 7 | GUI shows challenge/interstitial | Resolve challenge manually before automation | Do not start send/read automation while blocked |
| 8 | Text send works but attachment flow is blocked | Use file input or filechooser directly | Attachment is a separate path from text send |
| 9 | Worktree-local `cdp-bridge` is broken | Use a known-good `cdp-bridge` from another branch or shell | Transport can be swapped without rewriting the `qjs` layer |
| 10 | Thread source is healthy again | Return to one-shot checks and avoid polling loops | Recovery mode should end once the path is usable |

## Practical Notes

| Note | Meaning |
|---|---|
| `9222` vs `9223` | The port is usually not the root cause. Launch method, profile state, and GUI/headless mode matter more. |
| Saved profile | Convenient, but not automatically trustworthy |
| Fresh profile | Best diagnostic baseline |
| GUI/VNC | Temporary recovery tool, especially for login and challenge handling |
| `mjs` transport failures | Often really `cdp-bridge` failures |
| Successful send/read/attach once | Enough to switch back to one-shot collection |

## Recommended Default

| Situation | Recommended default |
|---|---|
| Need the fastest stable path | fresh profile + detached launch |
| Need manual login or challenge resolution | fresh GUI profile on `Xvfb` + `x11vnc` |
| Need long-term durable logic | move stateful logic into `hq.zig` |
| Need dynamic UI flexibility | keep the DOM logic in `qjs` |

## Long-Term Direction

| Layer | Desired long-term role |
|---|---|
| `qjs` | dynamic DOM and operational automation |
| `hq.zig` | app logic, durable state, SQLite, queue, batch, ingest |
| `chromedevtoolprotocol.zig` | reusable Zig CDP dependency |
| `cdp-bridge.zig` | transitional bridge, reduced in visibility over time |

The intended visible shape is `qjs + hq.zig`, even if a bridge still exists
internally for some time.
