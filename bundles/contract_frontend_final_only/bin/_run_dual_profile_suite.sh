#!/usr/bin/env bash
set -euo pipefail

SUITE_ROOT="${1:?usage: _run_dual_profile_suite.sh <suite_root> <core_rule> <audit_rule> <result_dir>}"
CORE_RULE="${2:?usage: _run_dual_profile_suite.sh <suite_root> <core_rule> <audit_rule> <result_dir>}"
AUDIT_RULE="${3:?usage: _run_dual_profile_suite.sh <suite_root> <core_rule> <audit_rule> <result_dir>}"
RESULT_DIR="${4:?usage: _run_dual_profile_suite.sh <suite_root> <core_rule> <audit_rule> <result_dir>}"
BASE="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$SUITE_ROOT/manifest.tsv"

source "$BASE/bin/_run_profile_suite.sh.lib"

NMO_BIN="$(resolve_nmo)"
[[ -f "$MANIFEST" ]] || { echo "manifest not found: $MANIFEST" >&2; exit 2; }
[[ -f "$CORE_RULE" ]] || { echo "rule not found: $CORE_RULE" >&2; exit 2; }
[[ -f "$AUDIT_RULE" ]] || { echo "rule not found: $AUDIT_RULE" >&2; exit 2; }

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
  core_dir="$out_dir/core"
  audit_dir="$out_dir/audit"
  notes=()
  mkdir -p "$core_dir" "$audit_dir"

  mk_import_dir "$CORE_RULE" "$facts_dir" "$core_dir/import"
  mk_import_dir "$AUDIT_RULE" "$facts_dir" "$audit_dir/import"

  "$NMO_BIN" "$CORE_RULE" -I "$core_dir/import" -D "$core_dir" -o --report none > "$core_dir/stdout.txt" 2> "$core_dir/stderr.txt" || notes+=("core_nmo_error")
  "$NMO_BIN" "$AUDIT_RULE" -I "$audit_dir/import" -D "$audit_dir" -o --report none > "$audit_dir/stdout.txt" 2> "$audit_dir/stderr.txt" || notes+=("audit_nmo_error")

  normalize_expected_violation "$case_dir/ExpectedCoreViolation.tsv" "$core_dir/debug_expected_violation.tsv"
  normalize_actual_violation "$core_dir/Violation.csv" "$core_dir/debug_actual_violation.tsv"
  diff -u "$core_dir/debug_expected_violation.tsv" "$core_dir/debug_actual_violation.tsv" > /dev/null || notes+=("core_violation_mismatch")

  normalize_expected_achieved "$case_dir/ExpectedCoreAchieved.tsv" "$core_dir/debug_expected_achieved.tsv"
  normalize_actual_achieved "$core_dir/Achieved.csv" "$core_dir/debug_actual_achieved.tsv"
  diff -u "$core_dir/debug_expected_achieved.tsv" "$core_dir/debug_actual_achieved.tsv" > /dev/null || notes+=("core_achieved_mismatch")

  normalize_expected_violation "$case_dir/ExpectedAuditViolation.tsv" "$audit_dir/debug_expected_violation.tsv"
  normalize_actual_violation "$audit_dir/Violation.csv" "$audit_dir/debug_actual_violation.tsv"
  diff -u "$audit_dir/debug_expected_violation.tsv" "$audit_dir/debug_actual_violation.tsv" > /dev/null || notes+=("audit_violation_mismatch")

  normalize_expected_achieved "$case_dir/ExpectedAuditAchieved.tsv" "$audit_dir/debug_expected_achieved.tsv"
  normalize_actual_achieved "$audit_dir/Achieved.csv" "$audit_dir/debug_actual_achieved.tsv"
  diff -u "$audit_dir/debug_expected_achieved.tsv" "$audit_dir/debug_actual_achieved.tsv" > /dev/null || notes+=("audit_achieved_mismatch")

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
  [[ -n "$note_text" ]] && echo "$status $case_id ($note_text)" || echo "$status $case_id"
done < "$MANIFEST"

pass_count=$((total - fail_count))
{
  printf 'suite\t%s\n' "$SUITE_ROOT"
  printf 'core_rule\t%s\n' "$CORE_RULE"
  printf 'audit_rule\t%s\n' "$AUDIT_RULE"
  printf 'total\t%s\n' "$total"
  printf 'pass\t%s\n' "$pass_count"
  printf 'fail\t%s\n' "$fail_count"
} > "$RESULT_DIR/summary.txt"
cat "$RESULT_DIR/summary.txt"

(( fail_count == 0 ))
