#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
trap cleanup_test_env EXIT

make_source_snapshot
printf '{"name":"fixture"}\n' > "$CHROME_SERVICE_SOURCE_PROFILE/Preferences"

run_sync_capture
test "$SYNC_RC" -eq 0
jq -e '.status == "green" and .reason_code == "OK"' > /dev/null <<<"$SYNC_JSON"

runtime_profile="$XDG_STATE_HOME/chromedevtoolprotocol-service/runtime/profile.current"
previous_profile="$XDG_STATE_HOME/chromedevtoolprotocol-service/runtime/profile.previous"

test -d "$runtime_profile"
test -f "$runtime_profile/Preferences"
test "$(cat "$runtime_profile/Preferences")" = '{"name":"fixture"}'
case "$(stat -c '%a' "$runtime_profile")" in
  700) ;;
  *) fail "runtime profile permissions are not owner-only" ;;
esac

touch "$runtime_profile/DevToolsActivePort" "$runtime_profile/SingletonLock"
printf '{"name":"fixture-2"}\n' > "$CHROME_SERVICE_SOURCE_PROFILE/Preferences"

run_sync_capture
test "$SYNC_RC" -eq 0
jq -e '.status == "green" and .reason_code == "OK"' > /dev/null <<<"$SYNC_JSON"
test -d "$previous_profile"
test ! -e "$runtime_profile/DevToolsActivePort"
test ! -e "$runtime_profile/SingletonLock"
test "$(cat "$runtime_profile/Preferences")" = '{"name":"fixture-2"}'

export CHROME_SERVICE_SOURCE_PROFILE="$runtime_profile"
run_sync_capture
test "$SYNC_RC" -eq 31
jq -e '.reason_code == "DIRECT_REUSE_FORBIDDEN"' > /dev/null <<<"$SYNC_JSON"

busy_source="$TMP_ROOT/busy-source"
mkdir -p "$busy_source"
touch "$busy_source/SingletonLock"
export CHROME_SERVICE_SOURCE_PROFILE="$busy_source"
run_sync_capture
test "$SYNC_RC" -eq 32
jq -e '.reason_code == "SOURCE_PROFILE_BUSY"' > /dev/null <<<"$SYNC_JSON"

printf 'ok\n'
