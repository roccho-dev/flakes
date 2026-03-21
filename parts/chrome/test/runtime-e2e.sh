#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
trap cleanup_test_env EXIT

make_source_snapshot
choose_port
start_service

wait_for_core_status green 60

jq -e '.core.status == "green"' > /dev/null <<<"$HEALTH_JSON"
jq -e '.core.cdp.version_ok == true and .core.cdp.list_ok == true' > /dev/null <<<"$HEALTH_JSON"
jq -e '.core.target.generic_attachable == true' > /dev/null <<<"$HEALTH_JSON"
jq -e '.core.process.running == true' > /dev/null <<<"$HEALTH_JSON"
jq -e '.app.chatgpt.status == "probe-failed"' > /dev/null <<<"$HEALTH_JSON"
jq -e '.app.chatgpt.reason_code == "APP_STATE_UNCERTAIN"' > /dev/null <<<"$HEALTH_JSON"
jq -e '.app.chatgpt.probe.ok == true' > /dev/null <<<"$HEALTH_JSON"
jq -e '.recovery.eligible == false and .recovery.reason_code == "CORE_GREEN"' > /dev/null <<<"$HEALTH_JSON"

stop_service
sleep 1
run_health_capture
test "$HEALTH_RC" -eq 20
jq -e '.core.status == "red" and .core.reason_code == "CDP_UNHEALTHY"' > /dev/null <<<"$HEALTH_JSON"

printf 'ok\n'
