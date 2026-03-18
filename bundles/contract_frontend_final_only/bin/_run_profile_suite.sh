#!/usr/bin/env bash
set -euo pipefail

SUITE_ROOT="${1:?usage: _run_profile_suite.sh <suite_root> <red|green> <rule_file> <result_dir>}"
SUITE_KIND="${2:?usage: _run_profile_suite.sh <suite_root> <red|green> <rule_file> <result_dir>}"
RULE="${3:?usage: _run_profile_suite.sh <suite_root> <red|green> <rule_file> <result_dir>}"
RESULT_DIR="${4:?usage: _run_profile_suite.sh <suite_root> <red|green> <rule_file> <result_dir>}"
BASE="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$SUITE_ROOT/manifest_${SUITE_KIND}.tsv"

source "$BASE/bin/_run_profile_suite.sh.lib"

NMO_BIN="$(resolve_nmo)"
if [[ ! -f "$RULE" ]]; then
  echo "rule not found: $RULE" >&2
  exit 2
fi
if [[ ! -f "$MANIFEST" ]]; then
  echo "manifest not found: $MANIFEST" >&2
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
  case_dir="$SUITE_ROOT/cases/$case_id"
  facts_dir="$case_dir/facts"
  out_dir="$RESULT_DIR/$case_id"
  import_dir="$out_dir/import"
  mkdir -p "$out_dir"
  notes=()

  mk_import_dir "$RULE" "$facts_dir" "$import_dir"

  if ! "$NMO_BIN" "$RULE" -I "$import_dir" -D "$out_dir" -o --report none > "$out_dir/stdout.txt" 2> "$out_dir/stderr.txt"; then
    notes+=("nmo_error")
  else
    rm -f "$out_dir/stdout.txt" "$out_dir/stderr.txt"
    normalize_expected_violation "$case_dir/ExpectedViolation.tsv" "$out_dir/debug_expected_violation.tsv"
    normalize_actual_violation "$out_dir/Violation.csv" "$out_dir/debug_actual_violation.tsv"
    if ! diff -u "$out_dir/debug_expected_violation.tsv" "$out_dir/debug_actual_violation.tsv" > /dev/null; then
      notes+=("Violation.csv mismatch")
    else
      rm -f "$out_dir/debug_expected_violation.tsv" "$out_dir/debug_actual_violation.tsv"
    fi

    normalize_expected_achieved "$case_dir/ExpectedAchieved.tsv" "$out_dir/debug_expected_achieved.tsv"
    normalize_actual_achieved "$out_dir/Achieved.csv" "$out_dir/debug_actual_achieved.tsv"
    if ! diff -u "$out_dir/debug_expected_achieved.tsv" "$out_dir/debug_actual_achieved.tsv" > /dev/null; then
      notes+=("Achieved.csv mismatch")
    else
      rm -f "$out_dir/debug_expected_achieved.tsv" "$out_dir/debug_actual_achieved.tsv"
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
done < "$MANIFEST"

pass_count=$((total - fail_count))
{
  printf 'suite\t%s\n' "$SUITE_ROOT"
  printf 'kind\t%s\n' "$SUITE_KIND"
  printf 'rule\t%s\n' "$RULE"
  printf 'total\t%s\n' "$total"
  printf 'pass\t%s\n' "$pass_count"
  printf 'fail\t%s\n' "$fail_count"
} > "$RESULT_DIR/summary.txt"
cat "$RESULT_DIR/summary.txt"

if (( fail_count > 0 )); then
  exit 1
fi
