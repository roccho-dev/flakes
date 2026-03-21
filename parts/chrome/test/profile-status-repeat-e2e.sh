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

make_seed_profile
printf '{"seed":"fixture"}\n' > "$CHROME_SERVICE_SEED_PROFILE/Preferences"
run_publish_capture
test "$PUBLISH_RC" -eq 0

start_fixture_server "$fixture_root"
export CHROME_SERVICE_APP_MATCH="http://127.0.0.1:$HTTP_PORT"
export CHROME_SERVICE_START_URL="http://127.0.0.1:$HTTP_PORT/logged-in.html"

for _ in $(seq 1 3); do
  run_profile_status_capture
  test "$PROFILE_STATUS_RC" -eq 0
  jq -e '.core.status == "green"' > /dev/null <<<"$PROFILE_STATUS_JSON"
  jq -e '.app.chatgpt.status == "logged-in" and .app.chatgpt.reason_code == "OK"' > /dev/null <<<"$PROFILE_STATUS_JSON"
done

test -d "$CHROME_SERVICE_PUBLISHED_SNAPSHOT"
test ! -e "$CHROME_SERVICE_PUBLISHED_SNAPSHOT/DevToolsActivePort"
test ! -e "$CHROME_SERVICE_PUBLISHED_SNAPSHOT/SingletonLock"
test "$(cat "$CHROME_SERVICE_PUBLISHED_SNAPSHOT/Preferences")" = '{"seed":"fixture"}'

printf 'ok\n'
