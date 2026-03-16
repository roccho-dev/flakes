#!/usr/bin/env bash
set -euo pipefail

SUITE="${1:?usage: _run_suite.sh <red|green>}"
BASE="$(cd "$(dirname "$0")/.." && pwd)"
RULE="$BASE/rules/contract_frontend_semantic_ir.nemo"
MANIFEST="$BASE/tests/manifest_${SUITE}.tsv"
RESULT_DIR="$BASE/results/$SUITE"
MK_IMPORT_DIR="$BASE/bin/mk_import_dir.sh"

resolve_nmo() {
  if [[ -n "${NMO:-}" ]]; then
    if [[ "$NMO" == */* ]]; then
      printf '%s\n' "$NMO"
    else
      command -v "$NMO" || printf '%s\n' "$NMO"
    fi
    return 0
  fi
  if [[ -e "$BASE/vendor/nmo" ]]; then
    printf '%s\n' "$BASE/vendor/nmo"
    return 0
  fi
  if command -v nmo > /dev/null 2>&1; then
    command -v nmo
    return 0
  fi
  return 1
}

if ! NMO_BIN="$(resolve_nmo)"; then
  echo "nmo not found: set NMO, add vendor/nmo, or place nmo on PATH" >&2
  exit 2
fi
if [[ "$NMO_BIN" == */* ]]; then
  if [[ ! -x "$NMO_BIN" ]]; then
    echo "nmo is not executable: $NMO_BIN" >&2
    exit 2
  fi
elif ! command -v "$NMO_BIN" > /dev/null 2>&1; then
  echo "nmo is not executable: $NMO_BIN" >&2
  exit 2
fi
if [[ ! -x "$MK_IMPORT_DIR" ]]; then
  echo "mk_import_dir.sh is not executable: $MK_IMPORT_DIR" >&2
  exit 2
fi
if [[ ! -f "$MANIFEST" ]]; then
  echo "manifest not found: $MANIFEST" >&2
  exit 2
fi

rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"
printf 'case_id	result	notes
' > "$RESULT_DIR/test_report.tsv"

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
    awk -F',' 'NF {print $1 "	" $2 "	" $3}' "$src" | LC_ALL=C sort > "$dst"
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

fail_count=0
total=0
while IFS=$'	' read -r case_id _; do
  [[ -z "$case_id" || "$case_id" == 'case_id' ]] && continue
  total=$((total + 1))
  case_dir="$BASE/tests/cases/$case_id"
  facts_dir="$case_dir/facts"
  out_dir="$RESULT_DIR/$case_id"
  import_dir="$out_dir/imports"
  mkdir -p "$out_dir"
  notes=()

  if ! "$MK_IMPORT_DIR" "$RULE" "$facts_dir" "$import_dir" > "$out_dir/stdout.txt" 2> "$out_dir/stderr.txt"; then
    notes+=("nmo_error")
  elif ! "$NMO_BIN" "$RULE" -I "$import_dir" -D "$out_dir" -o --report none >> "$out_dir/stdout.txt" 2>> "$out_dir/stderr.txt"; then
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
  printf '%s	%s	%s
' "$case_id" "$status" "$note_text" >> "$RESULT_DIR/test_report.tsv"
  if [[ -n "$note_text" ]]; then
    echo "$status $case_id ($note_text)"
  else
    echo "$status $case_id"
  fi
done < "$MANIFEST"

pass_count=$((total - fail_count))
{
  printf 'suite	%s
' "$SUITE"
  printf 'total	%s
' "$total"
  printf 'pass	%s
' "$pass_count"
  printf 'fail	%s
' "$fail_count"
} > "$RESULT_DIR/summary.txt"
cat "$RESULT_DIR/summary.txt"

if (( fail_count > 0 )); then
  exit 1
fi
