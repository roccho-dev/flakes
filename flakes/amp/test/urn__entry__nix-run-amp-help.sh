#!/usr/bin/env bash
set -euo pipefail
nix run .#amp -- --help >/dev/null
