#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
trap cleanup_test_env EXIT

fixture_root="$TMP_ROOT/fixtures"
mkdir -p "$fixture_root"

cat > "$fixture_root/logged-in.html" <<'EOF'
<!doctype html>
<html>
  <body>
    <main>
      <div id="prompt-textarea" contenteditable="true">ready</div>
    </main>
  </body>
</html>
EOF

cat > "$fixture_root/login-required.html" <<'EOF'
<!doctype html>
<html>
  <body>
    <div>Log in to continue</div>
    <form action="/login">
      <input type="password" />
    </form>
  </body>
</html>
EOF

make_source_snapshot
start_fixture_server "$fixture_root"
export CHROME_SERVICE_APP_MATCH="http://127.0.0.1:$HTTP_PORT"
choose_port

export CHROME_SERVICE_START_URL="http://127.0.0.1:$HTTP_PORT/logged-in.html"
start_service
wait_for_core_status green 60

run_health_capture_scope app
test "$HEALTH_RC" -eq 0
jq -e '.app.chatgpt.status == "logged-in" and .app.chatgpt.probe.executed == true' > /dev/null <<<"$HEALTH_JSON"

run_health_capture_scope core
test "$HEALTH_RC" -eq 0
jq -e '.service.health_scope == "core"' > /dev/null <<<"$HEALTH_JSON"
jq -e '.app.chatgpt.status == "logged-in"' > /dev/null <<<"$HEALTH_JSON"
jq -e '.app.chatgpt.probe.executed == false and .app.chatgpt.probe.cached == true and .app.chatgpt.probe.skipped_reason == "CORE_SCOPE"' > /dev/null <<<"$HEALTH_JSON"

stop_service
sleep 2
choose_port
export CHROME_SERVICE_START_URL="http://127.0.0.1:$HTTP_PORT/login-required.html"
start_service
wait_for_core_status green 60

run_health_capture_scope app
test "$HEALTH_RC" -eq 0
jq -e '.app.chatgpt.status == "login-required" and .app.chatgpt.reason_code == "LOGIN_REQUIRED"' > /dev/null <<<"$HEALTH_JSON"
jq -e '.app.chatgpt.cooldown.active == true and .app.chatgpt.probe.executed == true' > /dev/null <<<"$HEALTH_JSON"

run_health_capture_scope app
test "$HEALTH_RC" -eq 0
jq -e '.app.chatgpt.status == "login-required" and .app.chatgpt.reason_code == "LOGIN_REQUIRED"' > /dev/null <<<"$HEALTH_JSON"
jq -e '.app.chatgpt.cooldown.active == true and .app.chatgpt.probe.executed == false and .app.chatgpt.probe.cached == true and .app.chatgpt.probe.skipped_reason == "COOLDOWN_ACTIVE"' > /dev/null <<<"$HEALTH_JSON"

printf 'ok\n'
