#!/usr/bin/env bash
set -euo pipefail
nix shell .#amp -c amp --help >/dev/null
