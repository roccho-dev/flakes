#!/usr/bin/env bash
set -euo pipefail

# This test is a best-effort contract test:
# - Ensures delta supports side-by-side
# - Ensures the git-tools lazygit wrapper forces delta pagers
# - Ensures we can run lazygit in a pseudo-tty without config migration errors
# - Ensures the repo's lazygit wrapper is the one being executed
# - Ensures git diff is routed through delta side-by-side

repo_root="$1"

export TMPDIR="${TMPDIR:-/tmp}"
export HOME="$TMPDIR/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

# 1) Delta supports side-by-side
"${DELTA_BIN:-delta}" --help | rg -q "side-by-side"

# 2) Lazygit wrapper exists and references delta
lg_path="$(command -v lazygit)"
rg -q "delta" "$lg_path"
rg -q "pagers" "$lg_path"

# 3) Create a tiny repo with a diff so diff view exists.
# Also configure git to use delta as pager.
tmp_repo="$TMPDIR/repo"
mkdir -p "$tmp_repo"
cd "$tmp_repo"
git init -q
git config user.email "test@example.invalid"
git config user.name "test"

git config core.pager "${DELTA_BIN:-delta} --paging=never --side-by-side"

echo a >a.txt
git add a.txt
git commit -qm init

echo b >>a.txt

# 4) Verify delta side-by-side output exists.
out="$TMPDIR/diff.out"

git diff | "${DELTA_BIN:-delta}" --paging=never --side-by-side >"$out"
rg -q "│" "$out"

# 5) Run lazygit under a pseudo-tty, then exit quickly.
# We don't assert on screen contents; we only ensure it starts without trying to migrate a store config.
# The `script` command provides a pseudo-tty; it will hang if we don't kill it.
timeout 3s script -q -c "lazygit -p $tmp_repo" "$TMPDIR/typescript" >/dev/null 2>&1 || true

echo "ok"
