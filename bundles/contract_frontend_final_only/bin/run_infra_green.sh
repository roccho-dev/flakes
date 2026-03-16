#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
"$BASE/bin/_run_profile_suite.sh" "$BASE/tests/infra_import" green "$BASE/rules/probe_import.nemo" "$BASE/results/infra_import"
