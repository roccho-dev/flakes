#!/usr/bin/env bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")/.." && pwd)"

# This test validates runner resolution order by forcing NMO via env.
#
# IMPORTANT
# - Do not depend on $BASE/vendor/nmo being runnable (e.g. NixOS stub-ld).
# - The wrapper must call a working nmo so the suite can complete.

REAL_NMO=""
if [[ -n "${NMO:-}" && -x "$NMO" ]]; then
  REAL_NMO="$NMO"
elif command -v nmo >/dev/null 2>&1; then
  REAL_NMO="$(command -v nmo)"
else
  echo "nmo not found; run with NMO=<path> or ensure nmo is on PATH" >&2
  exit 2
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
MARKER="$TMPDIR/nmo_env_used.txt"
cat > "$TMPDIR/nmo-wrapper" <<WRAP
#!/bin/sh
set -eu
printf 'used\n' > "$MARKER"
exec "$REAL_NMO" "\$@"
WRAP
chmod +x "$TMPDIR/nmo-wrapper"
NMO="$TMPDIR/nmo-wrapper" "$BASE/bin/run_infra_green.sh"
[[ -f "$MARKER" ]]
echo "PASS runner_resolution"
