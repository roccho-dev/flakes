#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
unit="chrome-service-e2e-$$"

systemctl_user() {
  if [ -n "$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" ]; then
    XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" systemctl --user "$@"
  else
    XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" systemctl --user "$@"
  fi
}

systemd_run_user() {
  if [ -n "$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" ]; then
    XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS" systemd-run --user "$@"
  else
    XDG_RUNTIME_DIR="$SYSTEMD_BUS_XDG_RUNTIME_DIR" systemd-run --user "$@"
  fi
}

cleanup_unit() {
  systemctl_user stop "$unit" > /dev/null 2>&1 || true
  systemctl_user reset-failed "$unit" > /dev/null 2>&1 || true
}

cleanup_all() {
  cleanup_unit
  cleanup_test_env
}

trap cleanup_all EXIT

make_source_snapshot
choose_port

systemd_run_user \
  --unit "$unit" \
  --property=Restart=on-failure \
  --property=RestartSec=1 \
  --property=KillMode=control-group \
  --collect \
  --same-dir \
  --setenv=HOME="$HOME" \
  --setenv=XDG_STATE_HOME="$XDG_STATE_HOME" \
  --setenv=XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
  --setenv=CHROME_SERVICE_ADDR="$CHROME_SERVICE_ADDR" \
  --setenv=CHROME_SERVICE_PORT="$CHROME_SERVICE_PORT" \
  --setenv=CHROME_SERVICE_APP_MATCH="$CHROME_SERVICE_APP_MATCH" \
  --setenv=CHROME_SERVICE_START_URL="$CHROME_SERVICE_START_URL" \
  --setenv=CHROME_SERVICE_HEADLESS="$CHROME_SERVICE_HEADLESS" \
  --setenv=CHROME_SERVICE_SOURCE_PROFILE="$CHROME_SERVICE_SOURCE_PROFILE" \
  chromedevtoolprotocol-service > /dev/null

for _ in $(seq 1 20); do
  if [ "$(systemctl_user is-active "$unit" 2> /dev/null || true)" = "active" ]; then
    break
  fi
  sleep 1
done

test "$(systemctl_user is-active "$unit")" = "active"
wait_for_core_status green 60

pid_before="$(systemctl_user show --property MainPID --value "$unit")"
test "$pid_before" -gt 1

kill -KILL "$pid_before"

pid_after="$pid_before"
for _ in $(seq 1 30); do
  pid_after="$(systemctl_user show --property MainPID --value "$unit")"
  if [ "$(systemctl_user is-active "$unit" 2> /dev/null || true)" = "active" ] \
    && [ "$pid_after" -gt 1 ] \
    && [ "$pid_after" != "$pid_before" ]; then
    break
  fi
  sleep 1
done

test "$pid_after" -gt 1
test "$pid_after" != "$pid_before"
wait_for_core_status green 60

systemctl_user stop "$unit"
for _ in $(seq 1 20); do
  if [ "$(systemctl_user is-active "$unit" 2> /dev/null || true)" = "inactive" ]; then
    break
  fi
  sleep 1
done

test "$(systemctl_user is-active "$unit" 2> /dev/null || true)" = "inactive"

printf 'ok\n'
