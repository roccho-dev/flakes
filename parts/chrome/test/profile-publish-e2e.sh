#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
trap cleanup_test_env EXIT

make_seed_profile
printf '{"seed":"fixture"}\n' > "$CHROME_SERVICE_SEED_PROFILE/Preferences"

run_publish_capture
test "$PUBLISH_RC" -eq 0
jq -e '.status == "green" and .reason_code == "OK"' > /dev/null <<<"$PUBLISH_JSON"
test -d "$CHROME_SERVICE_PUBLISHED_SNAPSHOT"
test "$(cat "$CHROME_SERVICE_PUBLISHED_SNAPSHOT/Preferences")" = '{"seed":"fixture"}'

touch "$CHROME_SERVICE_SEED_PROFILE/SingletonLock"
run_publish_capture
test "$PUBLISH_RC" -eq 32
jq -e '.reason_code == "SEED_PROFILE_BUSY"' > /dev/null <<<"$PUBLISH_JSON"
rm -f "$CHROME_SERVICE_SEED_PROFILE/SingletonLock"

printf '{"seed":"fixture-2"}\n' > "$CHROME_SERVICE_SEED_PROFILE/Preferences"
run_publish_capture
test "$PUBLISH_RC" -eq 0
test -d "$CHROME_SERVICE_PUBLISHED_SNAPSHOT.previous"
test "$(cat "$CHROME_SERVICE_PUBLISHED_SNAPSHOT/Preferences")" = '{"seed":"fixture-2"}'

printf 'ok\n'
