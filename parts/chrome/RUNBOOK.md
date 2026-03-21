# Chrome Bootstrap Runbook

This runbook captures the proven headful bootstrap flow and the approved handoff:

`seed profile -> published snapshot -> runtime copy -> headless service`

## Rules

- Do not use main profile direct reuse for the service runtime.
- Do not build a CLI that accepts secrets or OTP values.
- Do not auto-promote runtime back into the canonical snapshot.
- Keep the headful login bootstrap separate from the headless service runtime.

## Package Provenance

- Use the flake-provided `chromium-cdp` package from this repo.
- Do not swap in ad-hoc `nixpkgs#chromium` commands during incident response.
- The proven launch path in this environment is the package behind:
  - `path:/home/nixos/repos/flakes/.worktrees/chrome-service#chromium-cdp`

## Paths

- Mutable headful seed profile:
  - `/home/nixos/.secret/hq/chromium-cdp-profile-140`
- Published snapshot target:
  - `/home/nixos/.secret/hq/chromium-cdp-profile.snapshot`
- Transient bootstrap run dir:
  - `/run/user/1000/chrome-login-9223/`

This runbook treats `/home/nixos/.secret/hq/chromium-cdp-profile-140` as the canonical mutable seed profile default.
- Log files:
  - `/run/user/1000/chrome-login-9223/xvfb.log`
  - `/run/user/1000/chrome-login-9223/x11vnc.log`
  - `/run/user/1000/chrome-login-9223/chromium.log`
- PID files:
  - `/run/user/1000/chrome-login-9223/xvfb.pid`
  - `/run/user/1000/chrome-login-9223/x11vnc.pid`
  - `/run/user/1000/chrome-login-9223/chromium.pid`

## Proven Successful Start Command

The exact proven `systemd --user` transient form from this session is:

```sh
/run/current-system/sw/bin/systemd-run --user --unit chrome-login-9223 \
  --property=Restart=on-failure \
  --property=RestartSec=1 \
  --property=KillMode=control-group \
  --collect \
  /run/current-system/sw/bin/nix shell 'path:/home/nixos/repos/flakes/.worktrees/chrome-service#chromium-cdp' \
    nixpkgs#bash nixpkgs#coreutils nixpkgs#curl nixpkgs#jq \
    nixpkgs#xorg.xorgserver nixpkgs#xorg.xdpyinfo nixpkgs#x11vnc \
    -c bash -c 'set -euo pipefail
cdp_port=9223
vnc_port=5901
display=":99"
profile="$HOME/.secret/hq/chromium-cdp-profile-140"
run_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/chrome-login-9223"
mkdir -p "$profile" "$run_dir"
chmod 700 "$profile" "$run_dir"
Xvfb "$display" -screen 0 1280x800x24 -nolisten tcp -ac >"$run_dir/xvfb.log" 2>&1 &
xvfb_pid=$!
for i in $(seq 1 80); do
  if xdpyinfo -display "$display" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
x11vnc -display "$display" -localhost -rfbport "$vnc_port" -forever -shared -nopw >"$run_dir/x11vnc.log" 2>&1 &
vnc_pid=$!
HQ_CHROME_ADDR=127.0.0.1 HQ_CHROME_PORT="$cdp_port" HQ_CHROME_HEADLESS=0 HQ_CHROME_PROFILE_DIR="$profile" DISPLAY="$display" chromium-cdp --disable-gpu --password-store=basic "https://chatgpt.com/" >"$run_dir/chromium.log" 2>&1 &
chrome_pid=$!
printf "%s\n" "$xvfb_pid" >"$run_dir/xvfb.pid"
printf "%s\n" "$vnc_pid" >"$run_dir/x11vnc.pid"
printf "%s\n" "$chrome_pid" >"$run_dir/chromium.pid"
wait "$chrome_pid"'
```

## Reusable Command Surface

The supported reusable entrypoint is:

```sh
chromedevtoolprotocol-service-profile-bootstrap start
chromedevtoolprotocol-service-profile-bootstrap verify
chromedevtoolprotocol-service-profile-bootstrap login-complete
chromedevtoolprotocol-service-profile-bootstrap stop
chromedevtoolprotocol-service-profile-bootstrap publish
```

### Start

Example:

```sh
CHROME_SERVICE_BOOTSTRAP_UNIT=chrome-login-9223 \
CHROME_SERVICE_BOOTSTRAP_RUN_DIR=/run/user/1000/chrome-login-9223 \
CHROME_SERVICE_BOOTSTRAP_PORT=9223 \
CHROME_SERVICE_BOOTSTRAP_VNC_PORT=5901 \
CHROME_SERVICE_BOOTSTRAP_DISPLAY=:99 \
CHROME_SERVICE_SEED_PROFILE=/home/nixos/.secret/hq/chromium-cdp-profile-140 \
chromedevtoolprotocol-service-profile-bootstrap start
```

### Verify

The required liveness checks are:

```sh
chromedevtoolprotocol-service-profile-bootstrap verify
systemctl --user is-active chrome-login-9223.service
curl -fsS --max-time 2 http://127.0.0.1:9223/json/version >/dev/null && echo cdp_up
bash -c '(echo > /dev/tcp/127.0.0.1/5901) >/dev/null 2>&1 && echo vnc_up'
```

### Login Complete Check

This checks the app readiness state without taking secrets or OTP values:

```sh
chromedevtoolprotocol-service-profile-bootstrap login-complete
```

Login completion is satisfied when:

- `.health.app.chatgpt.status == "logged-in"`

Bootstrap lane note:

- `login-complete` evaluates the bootstrap lane by `.login_complete`, not by the nested service health exit code alone.
- It is valid for `login_complete=true` while the nested health payload still shows `core.status=degraded`, because the bootstrap lane is only checking whether the seed profile is now logged in and ready to publish.

### Clean Shutdown

```sh
chromedevtoolprotocol-service-profile-bootstrap stop
systemctl --user stop chrome-login-9223.service
```

### Publish Handoff

After the headful seed profile is logged in and the browser is cleanly stopped, publish the approved snapshot by handoff only:

```sh
CHROME_SERVICE_SEED_PROFILE=/home/nixos/.secret/hq/chromium-cdp-profile-140 \
CHROME_SERVICE_PUBLISHED_SNAPSHOT=/home/nixos/.secret/hq/chromium-cdp-profile.snapshot \
chromedevtoolprotocol-service-profile-bootstrap publish
```

This copies `seed -> published snapshot` and does not auto-promote any runtime directory.

## Current Headless Conclusion

- Copied-profile headless remains the target path.
- Live ChatGPT currently still produces:
  - `app.chatgpt.status = challenge-blocked`
  - `app.chatgpt.reason_code = CHALLENGE_DETECTED`
  - `app.chatgpt.probe.title = Just a moment...`
- Therefore headful bootstrap is still needed as a recovery/bootstrap lane, even though the long-term target remains headless service use.

## Incident Table

| Incident | Cause | Fix | Recurrence Prevention |
|---|---|---|---|
| `git` missing from PATH | Minimal environment | Use `/run/current-system/sw/bin/git` | Always call git via absolute path in automation |
| `ssh` missing during push | Minimal environment | Use `nix shell nixpkgs#openssh nixpkgs#git -c git push ...` | Keep push flows wrapped in `nix shell` |
| `path:.#...` needed for flake commands | Flake resolution ambiguity | Use `path:.#...` consistently | Standardize all local flake commands on `path:.#` |
| `common.sh` missing in Nix store tests | Relative path broken in wrapped tests | Export `CHROME_SERVICE_TEST_DIR` and reference through it | Never rely on source-relative paths from wrapped test binaries |
| `systemctl --user` bus missing in tests | Test env overwrote `XDG_RUNTIME_DIR` | Preserve system bus vars and wrap `systemctl --user` | Keep separate runtime dirs for tests vs user bus |
| `rm/seq/sleep/cat` missing | Minimal shell environment | Add `nixpkgs#bash` and `nixpkgs#coreutils` in ad-hoc flows | Use `nix shell` with explicit tools for incident response |
| `bash` missing in `nix shell` | Shell package omitted | Add `nixpkgs#bash` | Treat `bash` as an explicit dependency |
| `DISPLAY` empty | No local GUI display in this CLI environment | Use `Xvfb` | Bootstrap headful flows through Xvfb, not direct local DISPLAY |
| `Xvfb` / `x11vnc` command not found | Wrong package names | Use `nixpkgs#xorg.xorgserver` and `nixpkgs#x11vnc` | Keep package names in the runbook and script |
| `5901 connection refused` | `x11vnc`/`Xvfb` tied to a short-lived session | Move lifecycle to `systemd-run --user` transient unit | Keep VNC bootstrap under systemd supervision |
| `9223` up but `5901` down | CDP and VNC are separate checks | Verify both separately | Require `9223`, `5901`, and `systemctl --user is-active` together |
| VNC viewer connection confusion | Port/display syntax ambiguity | Use `localhost:1` or `localhost::5901` | Put the viewer syntax in the runbook |
| Existing profile version mismatch suspicion | Profile version and browser provenance were unclear | Use the flake-provided `chromium-cdp` package and record provenance | Keep package provenance in runbook and avoid ad-hoc browser picks |
| Headful Chromium SIGTRAP crashes | Browser/profile/environment mismatch path | Validate with `coredumpctl`, then switch to the flake-provided launch path | Capture coredump evidence before changing launch assumptions |
| health app probe missing CDP bridge | `cdp-bridge` not present in health runtime | Inject `cdpBridge` into `parts/chrome/package.nix` | Keep transport helper as an explicit runtime dependency |
| `Just a moment...` not detected | DOM body alone was insufficient | Add title-based challenge detection | Probe title and body together |
| Current headless still blocked | Live anti-bot challenge remains | Classify as `challenge-blocked` instead of guessing | Keep bootstrap lane available until headless challenge conditions are understood |
