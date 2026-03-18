#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
"$BASE/bin/_run_profile_suite.sh" "$BASE/tests/audit" green "$BASE/rules/provenance_audit.nemo" "$BASE/results/audit/green"
