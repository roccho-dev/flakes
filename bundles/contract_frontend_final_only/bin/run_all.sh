#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
"$BASE/bin/test_runner_resolution.sh"
"$BASE/bin/run_infra_green.sh"
"$BASE/bin/run_core_red.sh"
"$BASE/bin/run_core_green.sh"
"$BASE/bin/run_audit_red.sh"
"$BASE/bin/run_audit_green.sh"
"$BASE/bin/run_runtime_suite.sh"
"$BASE/bin/run_final_only_gates.sh"
