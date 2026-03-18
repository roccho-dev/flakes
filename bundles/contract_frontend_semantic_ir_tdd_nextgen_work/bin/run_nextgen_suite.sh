#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
SUITES_FILE="$BASE/tests_next/SUITES.tsv"
SUITE="${1:?usage: run_nextgen_suite.sh <suite_name> [red|green|both]}"
MODE="${2:-both}"

if [[ ! -f "$SUITES_FILE" ]]; then
  echo "suite inventory not found: $SUITES_FILE" >&2
  exit 2
fi

DEFAULT_OUTPUTS=""
OUTPUT_PAIRS_REL=""
while IFS=$'\t' read -r suite_name default_outputs output_pairs_rel; do
  [[ -z "$suite_name" || "$suite_name" == 'suite_name' ]] && continue
  if [[ "$suite_name" == "$SUITE" ]]; then
    DEFAULT_OUTPUTS="$default_outputs"
    OUTPUT_PAIRS_REL="$output_pairs_rel"
    break
  fi
done < "$SUITES_FILE"

if [[ -z "$DEFAULT_OUTPUTS" ]]; then
  echo "unknown nextgen suite: $SUITE" >&2
  exit 2
fi

RULE_FILE="$BASE/rules/nextgen/$SUITE.nemo"
SUITE_ROOT="$BASE/tests_next/$SUITE"
CASES_ROOT="$SUITE_ROOT/cases"
OUTPUT_PAIRS_FILE=""
if [[ "$OUTPUT_PAIRS_REL" != '-' ]]; then
  OUTPUT_PAIRS_FILE="$BASE/$OUTPUT_PAIRS_REL"
fi

run_one() {
  local one_mode="$1"
  RULE_FILE="$RULE_FILE" \
  MANIFEST_FILE="$SUITE_ROOT/manifest_${one_mode}.tsv" \
  CASES_ROOT="$CASES_ROOT" \
  RESULT_DIR_OVERRIDE="$BASE/results/nextgen/$SUITE/$one_mode" \
  DEFAULT_OUTPUTS="$DEFAULT_OUTPUTS" \
  OUTPUT_PAIRS_FILE="$OUTPUT_PAIRS_FILE" \
  "$BASE/bin/_run_suite.sh" "$one_mode"
}

case "$MODE" in
  red|green)
    run_one "$MODE"
    ;;
  both|red-green)
    run_one red
    run_one green
    ;;
  *)
    echo "unknown mode: $MODE (expected red|green|both)" >&2
    exit 2
    ;;
esac
