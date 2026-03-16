#!/usr/bin/env bash
set -euo pipefail

BASE="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_DIR="$BASE/results/nextgen_cutover"
mkdir -p "$RESULT_DIR"
STATUS_FILE="$RESULT_DIR/status.tsv"

"$BASE/bin/run_nextgen_all.sh" both

pass=true
printf 'gate_id\tresult\tnotes\n' > "$STATUS_FILE"

check_done() {
  awk -F'\t' 'NR>1 && $2 != "DONE" {exit 1}' "$BASE/docs/NEXTGEN_MIGRATION_STEPS.tsv"
}
check_all_pass() {
  awk -F'\t' 'NR>1 && $3 != "PASS" {exit 1}' "$BASE/results/nextgen_all/summary_both.tsv"
}

if check_all_pass; then
  printf 'G01\tPASS\tall nextgen suites passed red+green\n' >> "$STATUS_FILE"
else
  printf 'G01\tFAIL\tnextgen suite failure present\n' >> "$STATUS_FILE"
  pass=false
fi

if [[ -f "$BASE/results/nextgen/whole_system_split/red/summary.txt" && -f "$BASE/results/nextgen/whole_system_split/green/summary.txt" ]]; then
  printf 'G02\tPASS\tdual verdict suite results present\n' >> "$STATUS_FILE"
else
  printf 'G02\tFAIL\tdual verdict suite outputs missing\n' >> "$STATUS_FILE"
  pass=false
fi

if [[ -f "$BASE/docs/NEXTGEN_FINAL_SPEC.tsv" ]] && check_done; then
  printf 'G03\tPASS\tfinal spec present and migration table fully DONE\n' >> "$STATUS_FILE"
else
  printf 'G03\tFAIL\tfinal spec missing or migration steps incomplete\n' >> "$STATUS_FILE"
  pass=false
fi

if [[ -f "$BASE/docs/NEXTGEN_PARITY_MATRIX.tsv" ]]; then
  printf 'G04\tPASS\tparity matrix present\n' >> "$STATUS_FILE"
else
  printf 'G04\tFAIL\tparity matrix missing\n' >> "$STATUS_FILE"
  pass=false
fi

if [[ -f "$BASE/docs/DEPRECATION__LEGACY_PATH.md" ]]; then
  printf 'G05\tPASS\tlegacy path freeze documented\n' >> "$STATUS_FILE"
else
  printf 'G05\tFAIL\tlegacy freeze note missing\n' >> "$STATUS_FILE"
  pass=false
fi

cat "$STATUS_FILE"
if [[ "$pass" != true ]]; then
  exit 1
fi
