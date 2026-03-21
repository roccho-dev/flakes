#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
trap cleanup_test_env EXIT

unit_name="chrome-bootstrap-smoke-$$"
run_dir="$TMP_ROOT/bootstrap-run"

systemctl_user() {
  if [ -n "$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" ]; then
    XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" systemctl --user "$@"
  else
    XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" systemctl --user "$@"
  fi
}

choose_display() {
  local candidate

  for candidate in 170 171 172 173 174 175; do
    if ! xdpyinfo -display ":$candidate" >/dev/null 2>&1; then
      printf ':%s' "$candidate"
      return 0
    fi
  done

  fail "unable to find a free X display"
}

make_seed_profile
choose_port
choose_http_port

export CHROME_SERVICE_BOOTSTRAP_UNIT="$unit_name"
export CHROME_SERVICE_BOOTSTRAP_RUN_DIR="$run_dir"
export CHROME_SERVICE_BOOTSTRAP_PORT="$CHROME_SERVICE_PORT"
export CHROME_SERVICE_BOOTSTRAP_VNC_PORT="$HTTP_PORT"
export CHROME_SERVICE_BOOTSTRAP_DISPLAY="$(choose_display)"
export CHROME_SERVICE_BOOTSTRAP_URL="about:blank"

systemctl_user stop "$unit_name" >/dev/null 2>&1 || true
systemctl_user reset-failed "$unit_name" >/dev/null 2>&1 || true

START_JSON="$(XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" chromedevtoolprotocol-service-profile-bootstrap start)"
jq -e '.status == "green"' > /dev/null <<<"$START_JSON"

VERIFY_JSON="$(XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" chromedevtoolprotocol-service-profile-bootstrap verify)"
jq -e '.status == "green" and .checks.unit_active == true and .checks.cdp_up == true and .checks.vnc_up == true' > /dev/null <<<"$VERIFY_JSON"

test -f "$run_dir/xvfb.log"
test -f "$run_dir/x11vnc.log"
test -f "$run_dir/chromium.log"
test -f "$run_dir/xvfb.pid"
test -f "$run_dir/x11vnc.pid"
test -f "$run_dir/chromium.pid"

STOP_JSON="$(XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" chromedevtoolprotocol-service-profile-bootstrap stop)"
jq -e '.status == "green" and .reason_code == "STOPPED"' > /dev/null <<<"$STOP_JSON"

test "$(systemctl_user is-active "$unit_name" 2> /dev/null || true)" != "active"

printf 'ok\n'
