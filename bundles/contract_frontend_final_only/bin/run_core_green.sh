#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
"$BASE/bin/_run_profile_suite.sh" "$BASE/tests/core" green "$BASE/rules/semantic_core.nemo" "$BASE/results/core/green"
