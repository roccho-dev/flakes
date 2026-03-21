#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
trap cleanup_test_env EXIT

run_recover_capture
test "$RECOVER_RC" -eq 40
jq -e '.reason_code == "RECOVERY_DISABLED" and .eligible == false and .executed == false' > /dev/null <<<"$RECOVER_JSON"

export CHROME_SERVICE_ALLOW_RECOVER="1"
run_recover_capture
test "$RECOVER_RC" -eq 41
jq -e '.reason_code == "RECOVERY_NOT_IMPLEMENTED" and .eligible == true and .executed == false' > /dev/null <<<"$RECOVER_JSON"

make_source_snapshot
choose_port
start_service
wait_for_core_status green 60

run_recover_capture
test "$RECOVER_RC" -eq 0
jq -e '.reason_code == "CORE_GREEN" and .eligible == false and .executed == false' > /dev/null <<<"$RECOVER_JSON"

printf 'ok\n'
