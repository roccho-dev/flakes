#!/usr/bin/env bash
set -euo pipefail

SUITE="${1:?usage: _run_suite.sh <red|green>}"
BASE="$(cd "$(dirname "$0")/.." && pwd)"
RULE_FILE="${RULE_FILE:-$BASE/rules/contract_frontend_semantic_ir.nemo}"
MANIFEST_FILE="${MANIFEST_FILE:-$BASE/tests/manifest_${SUITE}.tsv}"
CASES_ROOT="${CASES_ROOT:-$BASE/tests/cases}"
RESULT_DIR="${RESULT_DIR_OVERRIDE:-$BASE/results/$SUITE}"
DEFAULT_OUTPUTS="${DEFAULT_OUTPUTS:-1}"
OUTPUT_PAIRS_FILE="${OUTPUT_PAIRS_FILE:-}"

resolve_nmo() {
  if [[ -n "${NMO:-}" ]]; then
    if [[ ! -x "$NMO" ]]; then
      echo "NMO is set but not executable: $NMO" >&2
      exit 2
    fi
    printf '%s\n' "$NMO"
    return 0
  fi
  if [[ -x "$BASE/vendor/nmo" ]]; then
    printf '%s\n' "$BASE/vendor/nmo"
    return 0
  fi
  if command -v nmo >/dev/null 2>&1; then
    command -v nmo
    return 0
  fi
  echo "nmo executable not found (checked NMO env, vendor/nmo, PATH)" >&2
  exit 2
}

mk_import_dir() {
  local rule_file="$1" facts_dir="$2" import_dir="$3"
  local resources_file="$import_dir/.resources.list"
  rm -rf "$import_dir"
  mkdir -p "$import_dir"
  grep 'resource = "' "$rule_file" | sed -E 's/.*resource = "([^"]+)".*/\1/' | LC_ALL=C sort -u > "$resources_file"
  while IFS= read -r resource; do
    [[ -z "$resource" ]] && continue
    if [[ -f "$facts_dir/$resource" ]]; then
      cp "$facts_dir/$resource" "$import_dir/$resource"
    else
      : > "$import_dir/$resource"
    fi
  done < "$resources_file"
  rm -f "$resources_file"
}

normalize_expected_violation() {
  local src="$1" dst="$2"
  if [[ -s "$src" ]]; then
    sed '/^[[:space:]]*$/d' "$src" | LC_ALL=C sort > "$dst"
  else
    : > "$dst"
  fi
}
normalize_actual_violation() {
  local src="$1" dst="$2"
  if [[ -s "$src" ]]; then
    awk -F',' 'NF {print $1 "\t" $2 "\t" $3}' "$src" | LC_ALL=C sort > "$dst"
  else
    : > "$dst"
  fi
}
normalize_expected_achieved() {
  local src="$1" dst="$2"
  if [[ -s "$src" ]]; then
    sed '/^[[:space:]]*$/d' "$src" | LC_ALL=C sort > "$dst"
  else
    : > "$dst"
  fi
}
normalize_actual_achieved() {
  local src="$1" dst="$2"
  if [[ -s "$src" ]]; then
    awk -F',' 'NF {print $1}' "$src" | LC_ALL=C sort > "$dst"
  else
    : > "$dst"
  fi
}

compare_output_pair() {
  local case_dir="$1" out_dir="$2" label="$3" expected_rel="$4" actual_rel="$5" mode="$6"
  local expected_src="$case_dir/$expected_rel"
  local actual_src="$out_dir/$actual_rel"
  local expected_norm="$out_dir/debug_${label}_expected.tsv"
  local actual_norm="$out_dir/debug_${label}_actual.tsv"

  case "$mode" in
    violation)
      normalize_expected_violation "$expected_src" "$expected_norm"
      normalize_actual_violation "$actual_src" "$actual_norm"
      ;;
    achieved)
      normalize_expected_achieved "$expected_src" "$expected_norm"
      normalize_actual_achieved "$actual_src" "$actual_norm"
      ;;
    *)
      echo "unknown output compare mode: $mode" >&2
      exit 2
      ;;
  esac

  if ! diff -u "$expected_norm" "$actual_norm" > /dev/null; then
    notes+=("$label mismatch")
  else
    rm -f "$expected_norm" "$actual_norm"
  fi
}

NMO_BIN="$(resolve_nmo)"

if [[ ! -f "$RULE_FILE" ]]; then
  echo "rule not found: $RULE_FILE" >&2
  exit 2
fi
if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "manifest not found: $MANIFEST_FILE" >&2
  exit 2
fi
if [[ -n "$OUTPUT_PAIRS_FILE" && ! -f "$OUTPUT_PAIRS_FILE" ]]; then
  echo "output pairs file not found: $OUTPUT_PAIRS_FILE" >&2
  exit 2
fi

rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"
printf 'case_id\tresult\tnotes\n' > "$RESULT_DIR/test_report.tsv"

fail_count=0
total=0
while IFS=$'\t' read -r case_id _; do
  [[ -z "$case_id" || "$case_id" == 'case_id' ]] && continue
  total=$((total + 1))
  case_dir="$CASES_ROOT/$case_id"
  facts_dir="$case_dir/facts"
  out_dir="$RESULT_DIR/$case_id"
  import_dir="$out_dir/import_dir"
  mkdir -p "$out_dir"
  notes=()

  if [[ ! -d "$facts_dir" ]]; then
    notes+=("facts_dir_missing")
  else
    mk_import_dir "$RULE_FILE" "$facts_dir" "$import_dir"
    if ! "$NMO_BIN" "$RULE_FILE" -I "$import_dir" -D "$out_dir" -o --report none > "$out_dir/stdout.txt" 2> "$out_dir/stderr.txt"; then
      notes+=("nmo_error")
    else
      rm -f "$out_dir/stdout.txt" "$out_dir/stderr.txt"

      if [[ "$DEFAULT_OUTPUTS" != "0" ]]; then
        compare_output_pair "$case_dir" "$out_dir" "violation" "ExpectedViolation.tsv" "Violation.csv" "violation"
        compare_output_pair "$case_dir" "$out_dir" "achieved" "ExpectedAchieved.tsv" "Achieved.csv" "achieved"
      fi

      if [[ -n "$OUTPUT_PAIRS_FILE" ]]; then
        while IFS=$'\t' read -r label expected_rel actual_rel mode; do
          [[ -z "$label" || "$label" == 'label' ]] && continue
          compare_output_pair "$case_dir" "$out_dir" "$label" "$expected_rel" "$actual_rel" "$mode"
        done < "$OUTPUT_PAIRS_FILE"
      fi
    fi
  fi

  if (( ${#notes[@]} == 0 )); then
    status='PASS'
    note_text=''
  else
    status='FAIL'
    fail_count=$((fail_count + 1))
    note_text="$(printf '%s; ' "${notes[@]}")"
    note_text="${note_text%; }"
  fi
  printf '%s\t%s\t%s\n' "$case_id" "$status" "$note_text" >> "$RESULT_DIR/test_report.tsv"
  if [[ -n "$note_text" ]]; then
    echo "$status $case_id ($note_text)"
  else
    echo "$status $case_id"
  fi
done < "$MANIFEST_FILE"

pass_count=$((total - fail_count))
{
  printf 'suite\t%s\n' "$SUITE"
  printf 'total\t%s\n' "$total"
  printf 'pass\t%s\n' "$pass_count"
  printf 'fail\t%s\n' "$fail_count"
} > "$RESULT_DIR/summary.txt"
cat "$RESULT_DIR/summary.txt"

if (( fail_count > 0 )); then
  exit 1
fi
