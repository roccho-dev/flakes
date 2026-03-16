#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
"$BASE/bin/_run_dual_profile_suite.sh" "$BASE/tests/runtime"       "$BASE/rules/semantic_core.nemo"       "$BASE/rules/provenance_audit.nemo"       "$BASE/results/runtime"
