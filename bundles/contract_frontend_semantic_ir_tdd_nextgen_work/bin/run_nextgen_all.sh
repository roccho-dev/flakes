#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
SUITES_FILE="$BASE/tests_next/SUITES.tsv"
MODE="${1:-both}"
RESULT_ROOT="$BASE/results/nextgen_all"
mkdir -p "$RESULT_ROOT"
SUMMARY_FILE="$RESULT_ROOT/summary_${MODE}.tsv"
printf 'suite_name\tmode\tresult\n' > "$SUMMARY_FILE"

fail_count=0
while IFS=$'\t' read -r suite_name _ _; do
  [[ -z "$suite_name" || "$suite_name" == 'suite_name' ]] && continue
  if "$BASE/bin/run_nextgen_suite.sh" "$suite_name" "$MODE"; then
    printf '%s\t%s\tPASS\n' "$suite_name" "$MODE" >> "$SUMMARY_FILE"
  else
    printf '%s\t%s\tFAIL\n' "$suite_name" "$MODE" >> "$SUMMARY_FILE"
    fail_count=$((fail_count + 1))
  fi
done < "$SUITES_FILE"
cat "$SUMMARY_FILE"
if (( fail_count > 0 )); then
  exit 1
fi
