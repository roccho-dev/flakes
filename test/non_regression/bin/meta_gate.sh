#!/usr/bin/env bash
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/../../.." && pwd)"
BASELINES_DIR="$REPO_ROOT/test/non_regression/baselines"
RATIONALE_FILE="$REPO_ROOT/test/non_regression/rationale.tsv"

NORMALIZATION_VERSION="v1"

WRITE_BASELINE=0
if [[ "${1:-}" == "--write-baseline" ]]; then
  WRITE_BASELINE=1
  shift
fi

declare -A WRITE_SCOPE_OK=()
declare -A WRITE_PATH_SCOPE_OK=()

usage() {
  cat <<'EOF'
Usage:
  test/non_regression/bin/meta_gate.sh [--write-baseline]

Behavior:
  - Runs bundled contract suites (A/B/C) under a stable nmo.
  - Normalizes path-dependent text outputs.
  - Compares normalized outputs to baselines (or writes them).

Env:
  NMO: optional path to nmo executable (preferred)

Baseline Updates:
  When using --write-baseline, you must add a new last row to:
    test/non_regression/rationale.tsv
  with columns:
    who	why	affected_scope_labels	affected_scope_paths

  Only bundle labels listed in affected_scope_labels (comma-separated) will be
  overwritten. Use ALL to allow writing all baselines.
  Changed files must also stay within affected_scope_paths (comma-separated
  path prefixes relative to the bundle baseline root, or ALL).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

trim_ws() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

load_write_scope_from_rationale() {
  if [[ "$WRITE_BASELINE" != "1" ]]; then
    return 0
  fi

  if [[ ! -f "$RATIONALE_FILE" ]]; then
    echo "missing rationale file: $RATIONALE_FILE" >&2
    echo "create a TSV with header: who\twhy\taffected_scope_labels\taffected_scope_paths" >&2
    return 2
  fi

  local header
  IFS= read -r header <"$RATIONALE_FILE" 2>/dev/null || header=""
  if [[ "$header" != $'who\twhy\taffected_scope_labels\taffected_scope_paths'* ]]; then
    echo "invalid rationale header (expected prefix: who\\twhy\\taffected_scope_labels\\taffected_scope_paths): $RATIONALE_FILE" >&2
    echo "header: $header" >&2
    return 2
  fi

  local line
  line="$(tail -n +2 "$RATIONALE_FILE" 2>/dev/null | awk -F'\t' 'NF {last=$0} END {print last}')"
  if [[ -z "$line" ]]; then
    echo "rationale file has no entries: $RATIONALE_FILE" >&2
    echo "add a last row with: who\twhy\taffected_scope_labels\taffected_scope_paths" >&2
    return 2
  fi

  local who why scope path_scope _rest
  IFS=$'\t' read -r who why scope path_scope _rest <<<"$line"
  who="$(trim_ws "${who:-}")"
  why="$(trim_ws "${why:-}")"
  scope="$(trim_ws "${scope:-}")"
  path_scope="$(trim_ws "${path_scope:-}")"
  if [[ -z "$who" || -z "$why" || -z "$scope" || -z "$path_scope" ]]; then
    echo "invalid rationale last row (need who/why/affected_scope_labels/affected_scope_paths): $RATIONALE_FILE" >&2
    echo "last row: $line" >&2
    return 2
  fi

  WRITE_SCOPE_OK=()
  WRITE_PATH_SCOPE_OK=()
  if [[ "$scope" == "ALL" ]]; then
    WRITE_SCOPE_OK["ALL"]=1
  else
    local -a labels
    IFS=',' read -r -a labels <<<"$scope"
    local raw l
    for raw in "${labels[@]}"; do
      l="$(trim_ws "$raw")"
      [[ -z "$l" ]] && continue
      WRITE_SCOPE_OK["$l"]=1
    done

    if [[ "${#WRITE_SCOPE_OK[@]}" -eq 0 ]]; then
      echo "affected_scope_labels is empty in: $RATIONALE_FILE" >&2
      return 2
    fi
  fi

  if [[ "$path_scope" == "ALL" ]]; then
    WRITE_PATH_SCOPE_OK["ALL"]=1
    return 0
  fi

  local -a paths
  IFS=',' read -r -a paths <<<"$path_scope"
  local rawp p
  for rawp in "${paths[@]}"; do
    p="$(trim_ws "$rawp")"
    [[ -z "$p" ]] && continue
    WRITE_PATH_SCOPE_OK["$p"]=1
  done

  if [[ "${#WRITE_PATH_SCOPE_OK[@]}" -eq 0 ]]; then
    echo "affected_scope_paths is empty in: $RATIONALE_FILE" >&2
    return 2
  fi
}

write_scope_allows_label() {
  local label="$1"
  if [[ "$WRITE_BASELINE" != "1" ]]; then
    return 1
  fi
  if [[ -n "${WRITE_SCOPE_OK[ALL]:-}" ]]; then
    return 0
  fi
  [[ -n "${WRITE_SCOPE_OK[$label]:-}" ]]
}

list_changed_relative_paths() {
  local before_dir="$1"
  local after_dir="$2"

  local tmp_before tmp_after tmp_union
  tmp_before="$(mktemp)"
  tmp_after="$(mktemp)"
  tmp_union="$(mktemp)"

  (
    cd "$before_dir"
    find . -type f | sed 's|^\./||' | LC_ALL=C sort
  ) >"$tmp_before"
  (
    cd "$after_dir"
    find . -type f | sed 's|^\./||' | LC_ALL=C sort
  ) >"$tmp_after"
  cat "$tmp_before" "$tmp_after" | LC_ALL=C sort -u >"$tmp_union"

  local rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if [[ ! -f "$before_dir/$rel" || ! -f "$after_dir/$rel" ]]; then
      printf '%s\n' "$rel"
      continue
    fi
    if ! cmp -s "$before_dir/$rel" "$after_dir/$rel"; then
      printf '%s\n' "$rel"
    fi
  done <"$tmp_union"

  rm -f "$tmp_before" "$tmp_after" "$tmp_union"
}

path_scope_allows_relative_path() {
  local rel="$1"
  if [[ -n "${WRITE_PATH_SCOPE_OK[ALL]:-}" ]]; then
    return 0
  fi

  local prefix
  for prefix in "${!WRITE_PATH_SCOPE_OK[@]}"; do
    local norm_prefix="$prefix"
    norm_prefix="${norm_prefix%/}"
    if [[ "$rel" == "$norm_prefix" || "$rel" == "$norm_prefix"/* ]]; then
      return 0
    fi
  done
  return 1
}

enforce_changed_path_scope() {
  local label="$1"
  local baseline_dir="$2"
  local norm_dir="$3"

  if [[ "$WRITE_BASELINE" != "1" ]]; then
    return 0
  fi

  if [[ ! -d "$baseline_dir" ]]; then
    if [[ -n "${WRITE_PATH_SCOPE_OK[ALL]:-}" ]]; then
      return 0
    fi
    echo "baseline path-scope check requires existing baseline or affected_scope_paths=ALL: $label" >&2
    return 2
  fi

  local tmp_changed
  tmp_changed="$(mktemp)"
  list_changed_relative_paths "$baseline_dir" "$norm_dir" >"$tmp_changed"

  local rel bad=0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if ! path_scope_allows_relative_path "$rel"; then
      echo "baseline update path outside affected_scope_paths for $label: $rel" >&2
      bad=1
    fi
  done <"$tmp_changed"

  if [[ "$bad" == "1" ]]; then
    rm -f "$tmp_changed"
    echo "adjust affected_scope_paths in $RATIONALE_FILE or narrow the changes" >&2
    return 1
  fi

  rm -f "$tmp_changed"
}

sed_escape() {
  # Escape a literal string for use in sed s|||...||
  # shellcheck disable=SC2001
  printf '%s' "$1" | sed -e 's/[\\&|]/\\\\&/g'
}

resolve_nmo() {
  if [[ -n "${NMO:-}" && -x "${NMO}" ]]; then
    printf '%s' "$NMO"
    return 0
  fi

  if command -v nmo >/dev/null 2>&1; then
    command -v nmo
    return 0
  fi

  local tmpdir="$1"
  mkdir -p "$tmpdir"
  echo "nmo not found on PATH; building via nix: $REPO_ROOT#nmo" >&2
  nix build "$REPO_ROOT#nmo" -o "$tmpdir/nmo" >/dev/null
  printf '%s' "$tmpdir/nmo/bin/nmo"
}

sha256sum_one() {
  local p="$1"
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum not found on PATH" >&2
    return 2
  fi

  # Nix sandboxes often patch shebangs (e.g. /usr/bin/env -> /nix/store/...)
  # to make scripts runnable. For input digests, canonicalize shebang lines so
  # those environment-dependent edits do not cause false non-regressions.
  local first_line=""
  IFS= read -r first_line <"$p" 2>/dev/null || first_line=""
  if [[ "$first_line" == '#!'* ]]; then
    local canon
    canon="$(canonicalize_shebang_for_hash "$first_line")"
    {
      printf '%s\n' "$canon"
      tail -n +2 "$p" 2>/dev/null || true
    } | sha256sum | awk '{print $1}'
    return 0
  fi

  sha256sum "$p" | awk '{print $1}'
}

canonicalize_shebang_for_hash() {
  local line="$1"
  line="${line%$'\r'}"

  if [[ "$line" != '#!'* ]]; then
    printf '%s' "$line"
    return 0
  fi

  local rest="${line#\#!}"
  rest="${rest#"${rest%%[![:space:]]*}"}"

  local -a parts
  # shellcheck disable=SC2206
  parts=($rest)
  if [[ "${#parts[@]}" -eq 0 ]]; then
    printf '%s' "$line"
    return 0
  fi

  local cmd="${parts[0]}"
  local interp=""
  local -a args
  args=()

  if [[ "${cmd##*/}" == "env" ]]; then
    local i=1
    while [[ "$i" -lt "${#parts[@]}" ]]; do
      local a="${parts[$i]}"
      if [[ "$a" == "-S" || "$a" == "--split-string" ]]; then
        i=$((i + 1))
        if [[ "$i" -lt "${#parts[@]}" ]]; then
          interp="${parts[$i]##*/}"
          i=$((i + 1))
        fi
        break
      fi
      if [[ "$a" == -* ]]; then
        i=$((i + 1))
        continue
      fi
      if [[ "$a" == *=* && "$a" != */* ]]; then
        i=$((i + 1))
        continue
      fi
      interp="${a##*/}"
      i=$((i + 1))
      break
    done
    while [[ "$i" -lt "${#parts[@]}" ]]; do
      args+=("${parts[$i]}")
      i=$((i + 1))
    done
  else
    interp="${cmd##*/}"
    if [[ "${#parts[@]}" -gt 1 ]]; then
      args=("${parts[@]:1}")
    fi
  fi

  if [[ -z "$interp" ]]; then
    printf '%s' "$line"
    return 0
  fi

  local out="#!$interp"
  local a
  for a in "${args[@]}"; do
    out+=" $a"
  done
  printf '%s' "$out"
}

write_sha256sums_tsv() {
  local root="$1"
  local out_path="$2"
  shift 2

  mkdir -p "$(dirname "$out_path")"

  {
    printf 'sha256\tpath\n'
    (
      cd "$root"
      for p in "$@"; do
        [[ -e "$p" ]] || continue
        if [[ -d "$p" ]]; then
          find "$p" -type f
        else
          printf '%s\n' "$p"
        fi
      done
    ) | LC_ALL=C sort -u | while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      printf '%s\t%s\n' "$(sha256sum_one "$root/$rel")" "$rel"
    done
  } >"$out_path"
}

write_profile_manifest_tsv() {
  local norm_root="$1"
  local out_path="$2"
  local tmp_meta_dir="$3"

  mkdir -p "$(dirname "$out_path")"

  {
    printf 'profile_dir\tfile_count\ttree_digest_sha256\tsummary_digest_sha256\trunner_exit_code\n'

    if [[ ! -d "$norm_root/results" ]]; then
      return 0
    fi

    local tmp_dirs
    tmp_dirs="$(mktemp)"

    (
      cd "$norm_root/results"
      find . -type f \( -name 'summary.txt' -o -name 'test_report.tsv' \) \
        | sed 's|^\./||' \
        | xargs -r -n1 dirname \
        | LC_ALL=C sort -u
    ) >"$tmp_dirs"

    local rel dir file_count summary_digest tree_sums tree_digest exit_code
    exit_code="$(tr -d '\r' < "$norm_root/runner/exit_code.txt" 2>/dev/null || true)"
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      dir="$norm_root/results/$rel"
      file_count="$(find "$dir" -type f | wc -l | tr -d ' ')"
      if [[ -f "$dir/summary.txt" ]]; then
        summary_digest="$(sha256sum_one "$dir/summary.txt")"
      else
        summary_digest=""
      fi

      tree_sums="$tmp_meta_dir/profile_tree_$(printf '%s' "$rel" | tr '/ ' '__').tsv"
      write_sha256sums_tsv "$norm_root/results" "$tree_sums" "$rel"
      tree_digest="$(digest_of_sha256sums_tsv "$tree_sums")"

      printf '%s\t%s\t%s\t%s\t%s\n' "$rel" "$file_count" "$tree_digest" "$summary_digest" "$exit_code"
    done <"$tmp_dirs"

    rm -f "$tmp_dirs"
  } >"$out_path"
}

write_final_only_public_surface_tsv() {
  local label="$1"
  local bundle_root="$2"
  local out_path="$3"

  if [[ "$label" != "contract_frontend_final_only" ]]; then
    return 0
  fi

  write_sha256sums_tsv "$bundle_root" "$out_path" \
    "docs/FINAL_SPEC.tsv" \
    "rules" \
    "README.md" \
    "HOWTOUSE.md" \
    "bin/run_all.sh" \
    "bin/run_final_only_gates.sh"
}

extract_resolve_nmo_func() {
  local script_path="$1"
  local out_path="$2"

  awk '
    $0 ~ /^resolve_nmo\(\)[[:space:]]*\{/ {inside=1}
    inside {print}
    inside && $0 ~ /^[[:space:]]*\}[[:space:]]*$/ {exit}
  ' "$script_path" >"$out_path"

  if [[ ! -s "$out_path" ]]; then
    echo "failed to extract resolve_nmo() from: $script_path" >&2
    return 2
  fi
}

resolve_nmo_path_for_bundle() {
  local label="$1"
  local bundle_root="$2"
  local tmp_meta_dir="$3"

  case "$label" in
    contract_frontend_final_only)
      (cd "$bundle_root" && bash -c 'set -euo pipefail; source "bin/_run_profile_suite.sh.lib"; resolve_nmo')
      ;;

    contract_frontend_semantic_ir_tdd_ruleified|contract_frontend_semantic_ir_tdd_nextgen_work)
      local script_path="$bundle_root/bin/_run_suite.sh"
      local func_path="$tmp_meta_dir/resolve_nmo_extract_${label}.sh"
      extract_resolve_nmo_func "$script_path" "$func_path" || return 2
      BASE="$bundle_root" bash -c 'set -euo pipefail; source "$1"; resolve_nmo' bash "$func_path"
      ;;

    *)
      echo "unknown bundle label for nmo resolve probe: $label" >&2
      return 2
      ;;
  esac
}

write_nmo_resolution_probe_tsv() {
  local label="$1"
  local bundle_root="$2"
  local tmp_meta_dir="$3"

  local probe_dir="$tmp_meta_dir/nmo_resolution_probe"
  local env_stub="$probe_dir/env_nmo"
  local path_dir="$probe_dir/path_bin"
  local path_stub="$path_dir/nmo"
  local vendor_dir="$bundle_root/vendor"
  local vendor_stub="$vendor_dir/nmo"

  mkdir -p "$probe_dir" "$path_dir" "$vendor_dir"

  cat >"$env_stub" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$env_stub"

  cat >"$path_stub" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$path_stub"

  cat >"$vendor_stub" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$vendor_stub"

  local out_path="$tmp_meta_dir/NMO_RESOLUTION_PROBE.tsv"
  {
    printf 'case\texpected\tselected\tpass\n'

    local resolved selected pass

    # Case: NMO env wins.
    resolved="$(PATH="$path_dir:$PATH" NMO="$env_stub" resolve_nmo_path_for_bundle "$label" "$bundle_root" "$tmp_meta_dir")"
    if [[ "$resolved" == "$env_stub" ]]; then
      selected='env'
    elif [[ "$resolved" == "$vendor_stub" ]]; then
      selected='vendor'
    elif [[ "$resolved" == "$path_stub" ]]; then
      selected='path'
    else
      selected='unknown'
    fi
    pass='NO'
    [[ "$selected" == 'env' ]] && pass='YES'
    printf 'env\tenv\t%s\t%s\n' "$selected" "$pass"
    if [[ "$pass" != 'YES' ]]; then
      echo "nmo resolution probe failed for $label (env): resolved=$resolved" >&2
      return 1
    fi

    # Case: vendor beats PATH.
    resolved="$(
      unset NMO
      PATH="$path_dir:$PATH" resolve_nmo_path_for_bundle "$label" "$bundle_root" "$tmp_meta_dir"
    )"
    if [[ "$resolved" == "$env_stub" ]]; then
      selected='env'
    elif [[ "$resolved" == "$vendor_stub" ]]; then
      selected='vendor'
    elif [[ "$resolved" == "$path_stub" ]]; then
      selected='path'
    else
      selected='unknown'
    fi
    pass='NO'
    [[ "$selected" == 'vendor' ]] && pass='YES'
    printf 'vendor\tvendor\t%s\t%s\n' "$selected" "$pass"
    if [[ "$pass" != 'YES' ]]; then
      echo "nmo resolution probe failed for $label (vendor): resolved=$resolved" >&2
      return 1
    fi

    # Case: PATH when vendor missing.
    rm -f "$vendor_stub"
    resolved="$(
      unset NMO
      PATH="$path_dir:$PATH" resolve_nmo_path_for_bundle "$label" "$bundle_root" "$tmp_meta_dir"
    )"
    if [[ "$resolved" == "$env_stub" ]]; then
      selected='env'
    elif [[ "$resolved" == "$vendor_stub" ]]; then
      selected='vendor'
    elif [[ "$resolved" == "$path_stub" ]]; then
      selected='path'
    else
      selected='unknown'
    fi
    pass='NO'
    [[ "$selected" == 'path' ]] && pass='YES'
    printf 'path\tpath\t%s\t%s\n' "$selected" "$pass"
    if [[ "$pass" != 'YES' ]]; then
      echo "nmo resolution probe failed for $label (path): resolved=$resolved" >&2
      return 1
    fi
  } >"$out_path"
}

digest_of_sha256sums_tsv() {
  local tsv_path="$1"
  # Digest the content excluding the header.
  tail -n +2 "$tsv_path" | sha256sum | awk '{print $1}'
}

write_manifest_tsv_raw() {
  local out_path="$1"
  local label="$2"
  local bundle_rel="$3"
  local runner_rel="$4"
  local nmo_path="$5"
  local nmo_version="$6"
  local nmo_sha256="$7"
  local protected_digest="$8"
  local fixtures_digest="$9"
  local inputs_digest="${10}"
  local corpus_digest="${11}"

  mkdir -p "$(dirname "$out_path")"

  {
    printf 'key\tvalue\n'
    printf 'bundle_label\t%s\n' "$label"
    printf 'bundle_relpath\t%s\n' "$bundle_rel"
    printf 'entrypoint_relpath\t%s\n' "$runner_rel"
    printf 'platform_uname\t%s\n' "$(uname -s 2>/dev/null || true)"
    printf 'arch_uname\t%s\n' "$(uname -m 2>/dev/null || true)"
    printf 'resolved_nmo_path\t%s\n' "$nmo_path"
    printf 'resolved_nmo_version\t%s\n' "$nmo_version"
    printf 'resolved_nmo_sha256\t%s\n' "$nmo_sha256"
    printf 'normalization_version\t%s\n' "$NORMALIZATION_VERSION"
    printf 'protected_digest_sha256\t%s\n' "$protected_digest"
    printf 'fixtures_digest_sha256\t%s\n' "$fixtures_digest"
    printf 'inputs_digest_sha256\t%s\n' "$inputs_digest"
    printf 'corpus_digest_sha256\t%s\n' "$corpus_digest"
  } >"$out_path"
}

normalize_file() {
  local in_path="$1"
  local out_path="$2"
  local bundle_root="$3"
  local nmo_path="$4"

  mkdir -p "$(dirname "$out_path")"

  local esc_bundle esc_repo esc_home esc_nmo
  esc_bundle="$(sed_escape "$bundle_root")"
  esc_repo="$(sed_escape "$REPO_ROOT")"
  esc_home="$(sed_escape "${HOME:-/home}")"
  esc_nmo="$(sed_escape "$nmo_path")"

  # Normalize path-dependent fields. Keep this simple and conservative.
  # - bundle_root can vary (temp copies)
  # - repo_root can vary across machines
  # - $HOME can vary across machines
  # - nmo path can vary (/nix/store...)
  sed \
    -e "s|$esc_bundle|<BUNDLE_ROOT>|g" \
    -e "s|$esc_repo|<REPO_ROOT>|g" \
    -e "s|$esc_home|<HOME>|g" \
    -e "s|$esc_nmo|<NMO>|g" \
    "$in_path" >"$out_path"
}

normalize_tree() {
  local src_dir="$1"
  local dst_dir="$2"
  local bundle_root="$3"
  local nmo_path="$4"

  mkdir -p "$dst_dir"

  shopt -s nullglob globstar
  local p rel dst
  for p in "$src_dir"/**; do
    rel="${p#"$src_dir/"}"
    dst="$dst_dir/$rel"

    if [[ -d "$p" ]]; then
      mkdir -p "$dst"
      continue
    fi

    mkdir -p "$(dirname "$dst")"

    case "$p" in
      *.tsv|*.dsv|*.txt|*.log)
        normalize_file "$p" "$dst" "$bundle_root" "$nmo_path"
        ;;
      *)
        cp -a "$p" "$dst"
        ;;
    esac
  done
}

diff_or_write_baseline() {
  local norm_dir="$1"
  local baseline_dir="$2"
  local label="$3"

  if [[ "$WRITE_BASELINE" == "1" ]]; then
    if write_scope_allows_label "$label"; then
      if ! enforce_changed_path_scope "$label" "$baseline_dir" "$norm_dir"; then
        return 1
      fi
      rm -rf "$baseline_dir"
      mkdir -p "$(dirname "$baseline_dir")"
      cp -a "$norm_dir" "$baseline_dir"
      echo "WROTE baseline: $label" >&2
      return 0
    fi

    # Scope forbids writing this label; still require it to match.
    if [[ ! -d "$baseline_dir" ]]; then
      echo "missing baseline (scope forbids writing): $baseline_dir" >&2
      echo "add label to affected_scope_labels in $RATIONALE_FILE (or set ALL)" >&2
      return 2
    fi
    if ! diff -ru "$baseline_dir" "$norm_dir" >/dev/null; then
      echo "baseline mismatch (scope forbids update): $label" >&2
      diff -ru "$baseline_dir" "$norm_dir" | sed -n '1,200p' >&2 || true
      echo "add label to affected_scope_labels in $RATIONALE_FILE (or set ALL)" >&2
      return 1
    fi
    return 0
  fi

  if [[ ! -d "$baseline_dir" ]]; then
    echo "missing baseline: $baseline_dir" >&2
    echo "run with --write-baseline to initialize" >&2
    return 2
  fi

  if ! diff -ru "$baseline_dir" "$norm_dir" >/dev/null; then
    echo "baseline mismatch: $label" >&2
    diff -ru "$baseline_dir" "$norm_dir" | sed -n '1,200p' >&2 || true
    return 1
  fi
}

run_bundle() {
  local label="$1"
  local bundle_rel="$2"
  local runner_rel="$3"
  local tmp_root="$4"
  local nmo_path="$5"

  local bundle_src="$REPO_ROOT/$bundle_rel"
  if [[ ! -d "$bundle_src" ]]; then
    echo "bundle not found: $bundle_src" >&2
    return 2
  fi

  local tmp_bundle="$tmp_root/$label/bundle"
  local tmp_out="$tmp_root/$label/out"
  local tmp_norm="$tmp_root/$label/norm"
  local tmp_meta="$tmp_root/$label/meta"

  mkdir -p "$tmp_bundle" "$tmp_out" "$tmp_norm" "$tmp_meta"

  # Copy into temp to avoid mutating git worktree.
  cp -a "$bundle_src/." "$tmp_bundle/"

  # Bundles sometimes ship precomputed results; those are not part of the
  # observable corpus we gate. Always regenerate from a clean slate.
  rm -rf "$tmp_bundle/results"

  # Contract probe: ensure nmo resolution order is proven mechanically.
  write_nmo_resolution_probe_tsv "$label" "$tmp_bundle" "$tmp_meta"

  local runner="$tmp_bundle/$runner_rel"
  if [[ ! -x "$runner" ]]; then
    echo "runner not executable: $runner" >&2
    return 2
  fi

  echo "RUN $label: $bundle_rel ($runner_rel)" >&2

  set +e
  (cd "$tmp_bundle" && NMO="$nmo_path" "$runner") >"$tmp_out/stdout.txt" 2>"$tmp_out/stderr.txt"
  local rc="$?"
  set -e

  printf '%s\n' "$rc" >"$tmp_out/exit_code.txt"

  if [[ "$rc" != "0" ]]; then
    echo "FAIL $label: runner exit $rc" >&2
    echo "  stdout: $tmp_out/stdout.txt" >&2
    echo "  stderr: $tmp_out/stderr.txt" >&2
    return "$rc"
  fi

  if [[ ! -d "$tmp_bundle/results" ]]; then
    echo "FAIL $label: results dir missing after run" >&2
    return 2
  fi

  normalize_tree "$tmp_bundle/results" "$tmp_norm/results" "$tmp_bundle" "$nmo_path"
  normalize_file "$tmp_out/stdout.txt" "$tmp_norm/runner/stdout.txt" "$tmp_bundle" "$nmo_path"
  normalize_file "$tmp_out/stderr.txt" "$tmp_norm/runner/stderr.txt" "$tmp_bundle" "$nmo_path"
  cp -a "$tmp_out/exit_code.txt" "$tmp_norm/runner/exit_code.txt"

  # ---- Meta evidence (inputs + corpus + nmo identity) ----
  local nmo_version nmo_sha256
  nmo_version="$($nmo_path --version 2>/dev/null | tr -d '\r' | head -n 1 || true)"
  nmo_sha256="$(sha256sum_one "$nmo_path")"

  # Inputs digests (expand scope beyond rules+tests+bin).
  write_sha256sums_tsv "$tmp_bundle" "$tmp_meta/PROTECTED_SHA256SUMS.tsv" \
    "bin" "rules" "HOWTOUSE.md" "README.md"
  write_sha256sums_tsv "$tmp_bundle" "$tmp_meta/FIXTURES_SHA256SUMS.tsv" \
    "tests" "tests_next"
  write_sha256sums_tsv "$tmp_bundle" "$tmp_meta/INPUTS_SHA256SUMS.tsv" \
    "bin" "rules" "tests" "tests_next" "HOWTOUSE.md" "README.md"

  local protected_digest fixtures_digest inputs_digest
  protected_digest="$(digest_of_sha256sums_tsv "$tmp_meta/PROTECTED_SHA256SUMS.tsv")"
  fixtures_digest="$(digest_of_sha256sums_tsv "$tmp_meta/FIXTURES_SHA256SUMS.tsv")"
  inputs_digest="$(digest_of_sha256sums_tsv "$tmp_meta/INPUTS_SHA256SUMS.tsv")"

  # Corpus digests (normalized observable outputs only).
  write_sha256sums_tsv "$tmp_norm" "$tmp_meta/CORPUS_SHA256SUMS.tsv" \
    "results" "runner"
  local corpus_digest
  corpus_digest="$(digest_of_sha256sums_tsv "$tmp_meta/CORPUS_SHA256SUMS.tsv")"

  write_profile_manifest_tsv "$tmp_norm" "$tmp_meta/PROFILE_MANIFEST.tsv" "$tmp_meta"
  write_final_only_public_surface_tsv "$label" "$tmp_bundle" "$tmp_meta/PUBLIC_SURFACE_SHA256SUMS.tsv"

  # Manifest (normalize path-dependent fields).
  write_manifest_tsv_raw \
    "$tmp_meta/MANIFEST.raw" \
    "$label" \
    "$bundle_rel" \
    "$runner_rel" \
    "$nmo_path" \
    "$nmo_version" \
    "$nmo_sha256" \
    "$protected_digest" \
    "$fixtures_digest" \
    "$inputs_digest" \
    "$corpus_digest"

  normalize_file "$tmp_meta/MANIFEST.raw" "$tmp_norm/meta/MANIFEST.tsv" "$tmp_bundle" "$nmo_path"
  cp -a "$tmp_meta/"*.tsv "$tmp_norm/meta/"

  local baseline_dir="$BASELINES_DIR/$label"
  if ! diff_or_write_baseline "$tmp_norm" "$baseline_dir" "$label"; then
    echo "FAIL $label" >&2
    return 1
  fi
  echo "PASS $label" >&2
}

main() {
  local tmp_root
  tmp_root="$(mktemp -d)"
  # NOTE: trap runs after this function returns; capture value now.
  trap "rm -rf \"$tmp_root\"" EXIT

  local nmo_path
  nmo_path="$(resolve_nmo "$tmp_root")"

  load_write_scope_from_rationale

  mkdir -p "$BASELINES_DIR"

  run_bundle \
    "contract_frontend_final_only" \
    "bundles/contract_frontend_final_only" \
    "bin/run_all.sh" \
    "$tmp_root" \
    "$nmo_path"

  run_bundle \
    "contract_frontend_semantic_ir_tdd_ruleified" \
    "bundles/contract_frontend_semantic_ir_tdd_ruleified" \
    "bin/run_red_green.sh" \
    "$tmp_root" \
    "$nmo_path"

  run_bundle \
    "contract_frontend_semantic_ir_tdd_nextgen_work" \
    "bundles/contract_frontend_semantic_ir_tdd_nextgen_work" \
    "bin/check_nextgen_cutover.sh" \
    "$tmp_root" \
    "$nmo_path"
}

main
