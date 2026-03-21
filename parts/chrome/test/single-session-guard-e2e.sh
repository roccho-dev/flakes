#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=parts/chrome/test/common.sh
. "$script_dir/common.sh"

setup_test_env
trap cleanup_test_env EXIT

make_seed_profile
make_source_snapshot
export CHROME_SERVICE_PUBLISHED_SNAPSHOT="$TMP_ROOT/published-snapshot"
export CHROME_SERVICE_SOURCE_PROFILE="$TMP_ROOT/source-profile"
export CHROME_SERVICE_BOOTSTRAP_UNIT="chrome-bootstrap-guard-$$"
export CHROME_SERVICE_BOOTSTRAP_RUN_DIR="$TMP_ROOT/bootstrap-run"
export CHROME_SERVICE_BOOTSTRAP_PORT="39223"
export CHROME_SERVICE_BOOTSTRAP_VNC_PORT="39591"
export CHROME_SERVICE_BOOTSTRAP_DISPLAY=":177"
choose_port
start_service
wait_for_core_status green 60

set +e
bootstrap_output="$(chromedevtoolprotocol-service-profile-bootstrap start 2>&1)"
bootstrap_rc=$?
set -e

test "$bootstrap_rc" -eq 42
case "$bootstrap_output" in
  *SINGLE_SESSION_LOCKED*) ;;
  *) fail "bootstrap did not report SINGLE_SESSION_LOCKED" ;;
esac

printf 'ok\n'
