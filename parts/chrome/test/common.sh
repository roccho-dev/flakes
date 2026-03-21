set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

setup_test_env() {
  TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/chrome-service-test.XXXXXX")"
  export TMP_ROOT

  export SYSTEMD_BUS_XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  export SYSTEMD_BUS_DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}"

  export HOME="$TMP_ROOT/home"
  export XDG_STATE_HOME="$TMP_ROOT/state"
  export XDG_RUNTIME_DIR="$TMP_ROOT/run"
  export CHROME_SERVICE_ADDR="127.0.0.1"
  export CHROME_SERVICE_APP_MATCH="about:blank"
  export CHROME_SERVICE_START_URL="about:blank"
  export CHROME_SERVICE_HEADLESS="1"
  export CHROME_SERVICE_ALLOW_RECOVER="0"
  export CHROME_SERVICE_SEED_PROFILE="$TMP_ROOT/seed-profile"
  export CHROME_SERVICE_PUBLISHED_SNAPSHOT="$TMP_ROOT/published-snapshot"
  export CHROME_SERVICE_SOURCE_PROFILE="$TMP_ROOT/source-profile"

  mkdir -p "$HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
}

cleanup_test_env() {
  stop_fixture_server
  stop_service
  if [ -n "${TMP_ROOT:-}" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
}

make_source_snapshot() {
  rm -rf "$CHROME_SERVICE_SOURCE_PROFILE"
  mkdir -p "$CHROME_SERVICE_SOURCE_PROFILE"
}

choose_named_port() {
  local var_name="$1"
  local port
  local attempt

  for attempt in $(seq 1 50); do
    port=$((20000 + RANDOM % 20000))
    if ! curl -fsS --max-time 1 "http://127.0.0.1:$port/json/version" > /dev/null 2>&1; then
      printf -v "$var_name" '%s' "$port"
      export "$var_name"
      return 0
    fi
  done

  fail "unable to find an unused localhost port"
}

choose_port() {
  choose_named_port CHROME_SERVICE_PORT
}

choose_http_port() {
  choose_named_port HTTP_PORT
}

run_health_capture() {
  run_health_capture_scope app
}

run_health_capture_scope() {
  local scope="$1"
  local rc

  set +e
  HEALTH_JSON="$(CHROME_SERVICE_HEALTH_SCOPE="$scope" chromedevtoolprotocol-service-health 2> /dev/null)"
  rc=$?
  set -e

  export HEALTH_JSON
  export HEALTH_RC="$rc"
}

run_recover_capture() {
  local rc

  set +e
  RECOVER_JSON="$(chromedevtoolprotocol-service-recover 2> /dev/null)"
  rc=$?
  set -e

  export RECOVER_JSON
  export RECOVER_RC="$rc"
}

run_sync_capture() {
  local rc

  set +e
  SYNC_JSON="$(chromedevtoolprotocol-service-profile-sync 2> /dev/null)"
  rc=$?
  set -e

  export SYNC_JSON
  export SYNC_RC="$rc"
}

run_publish_capture() {
  local rc

  set +e
  PUBLISH_JSON="$(chromedevtoolprotocol-service-profile-publish 2> /dev/null)"
  rc=$?
  set -e

  export PUBLISH_JSON
  export PUBLISH_RC="$rc"
}

run_profile_status_capture() {
  local rc

  set +e
  PROFILE_STATUS_JSON="$(chromedevtoolprotocol-service-profile-status 2> /dev/null)"
  rc=$?
  set -e

  export PROFILE_STATUS_JSON
  export PROFILE_STATUS_RC="$rc"
}

make_seed_profile() {
  rm -rf "$CHROME_SERVICE_SEED_PROFILE"
  mkdir -p "$CHROME_SERVICE_SEED_PROFILE"
}

start_service() {
  : > "$TMP_ROOT/service.stdout"
  : > "$TMP_ROOT/service.stderr"
  chromedevtoolprotocol-service > "$TMP_ROOT/service.stdout" 2> "$TMP_ROOT/service.stderr" &
  SERVICE_PID=$!
  export SERVICE_PID
}

stop_service() {
  if [ -n "${SERVICE_PID:-}" ] && kill -0 "$SERVICE_PID" 2> /dev/null; then
    kill "$SERVICE_PID" 2> /dev/null || true
    wait "$SERVICE_PID" 2> /dev/null || true
  fi

  unset SERVICE_PID || true
}

start_fixture_server() {
  local root="$1"

  choose_http_port
  python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$root" > "$TMP_ROOT/http.stdout" 2> "$TMP_ROOT/http.stderr" &
  HTTP_PID=$!
  export HTTP_PID

  for _ in $(seq 1 20); do
    if curl -fsS --max-time 1 "http://127.0.0.1:$HTTP_PORT/" > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  fail "fixture server did not start"
}

stop_fixture_server() {
  if [ -n "${HTTP_PID:-}" ] && kill -0 "$HTTP_PID" 2> /dev/null; then
    kill "$HTTP_PID" 2> /dev/null || true
    wait "$HTTP_PID" 2> /dev/null || true
  fi

  unset HTTP_PID || true
}

wait_for_core_status() {
  local target="$1"
  local attempts="${2:-60}"
  local attempt

  for attempt in $(seq 1 "$attempts"); do
    run_health_capture
    if [ -n "$HEALTH_JSON" ] && jq -e --arg target "$target" '.core.status == $target' > /dev/null <<<"$HEALTH_JSON"; then
      return 0
    fi
    sleep 1
  done

  printf '%s\n' "$HEALTH_JSON" > "$TMP_ROOT/last-health.json"
  fail "timed out waiting for core.status=$target"
}
