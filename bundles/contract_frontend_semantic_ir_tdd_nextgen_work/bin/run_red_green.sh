#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./run_red.sh
./run_green.sh
