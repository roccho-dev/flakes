#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE"

fail() { echo "FAIL $1" >&2; exit 1; }

legacy_paths=(
  "rules/contract_frontend_semantic_ir.nemo"
  "bin/_run_suite.sh"
  "bin/run_red.sh"
  "bin/run_green.sh"
  "bin/run_red_green.sh"
  "docs/TDD_MATRIX.tsv"
  "docs/RED_TO_GREEN.tsv"
  "docs/SEMANTIC_IR_FACTS.tsv"
  "docs/ANALYSIS.md"
  "docs/ARCHITECTURE__contract_frontend_semantic_ir_tdd.html"
  "docs/EXECUTIVE_SUMMARY.txt"
  "docs/LOWERING_PRESENCE_ADOPTION.md"
  "docs/OBJECTIONS_RESOLUTION.md"
  "docs/SOURCE_PROPOSAL.md"
  "docs/SOURCE_PROPOSAL_ARCHITECTURE.html"
  "docs/WAVES.tsv"
  "docs/FINAL_ACCEPTANCE__final_only.tsv"
  "docs/MIGRATION_STEPS__final_only_detailed.tsv"
  "docs/MIGRATION_ROADMAP__final_only.html"
  "docs/CURRENT_PROGRESS__actual_repo.txt"
  "tests/hash_manifest.tsv"
  "tests/manifest_red.tsv"
  "tests/manifest_green.tsv"
  "tests/cases"
  "results/red"
  "results/green"
  "run_red_stdout.txt"
  "run_green_stdout.txt"
  "run_red_green_stdout.txt"
)
for path in "${legacy_paths[@]}"; do
  [[ ! -e "$path" ]] || fail "legacy_path_present:$path"
done

if find . -path './.git' -prune -o -type f | grep -q 'v2'; then
  fail "transitional_v2_name_present"
fi

if grep -RIn --exclude-dir=.git --exclude-dir=vendor --exclude=.gitignore --exclude=run_final_only_gates.sh 'ClauseWitnessObligation' README.md HOWTOUSE.md docs rules bin tests >/dev/null 2>&1; then
  fail "obsolete_clause_witness_obligation_present"
fi

if [[ -n "$(git status --porcelain=v1 --untracked-files=no)" ]]; then
  fail "tracked_tree_dirty"
fi

echo "PASS final_only_gates"
