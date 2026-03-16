#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./_run_suite.sh green
