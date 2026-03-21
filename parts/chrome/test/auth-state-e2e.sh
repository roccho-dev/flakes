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
    <form action="/login">
      <input type="password" />
    </form>
  </body>
</html>
EOF

cat > "$fixture_root/challenge-blocked.html" <<'EOF'
<!doctype html>
<html>
  <body>
    <button>I am human</button>
    <div>Verify you are human to continue</div>
  </body>
</html>
EOF

cat > "$fixture_root/challenge-title.html" <<'EOF'
<!doctype html>
<html>
  <head>
    <title>Just a moment...</title>
  </head>
  <body></body>
</html>
EOF

make_source_snapshot
start_fixture_server "$fixture_root"
export CHROME_SERVICE_APP_MATCH="http://127.0.0.1:$HTTP_PORT"

run_case() {
  local page="$1"
  local expected_status="$2"
  local expected_reason="$3"

  stop_service
  choose_port
  export CHROME_SERVICE_START_URL="http://127.0.0.1:$HTTP_PORT/$page"
  start_service
  wait_for_core_status green 60

  jq -e --arg expected "$expected_status" '.app.chatgpt.status == $expected' > /dev/null <<<"$HEALTH_JSON"
  jq -e --arg expected "$expected_reason" '.app.chatgpt.reason_code == $expected' > /dev/null <<<"$HEALTH_JSON"
  jq -e '.app.chatgpt.probe.ok == true' > /dev/null <<<"$HEALTH_JSON"
}

run_case "logged-in.html" "logged-in" "OK"
run_case "login-required.html" "login-required" "LOGIN_REQUIRED"
run_case "challenge-blocked.html" "challenge-blocked" "CHALLENGE_DETECTED"
run_case "challenge-title.html" "challenge-blocked" "CHALLENGE_DETECTED"

printf 'ok\n'
