#!/usr/bin/env bash
set -euo pipefail
nix build .#amp --print-build-logs
