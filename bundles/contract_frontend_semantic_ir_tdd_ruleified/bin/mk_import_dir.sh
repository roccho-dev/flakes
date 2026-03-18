#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: mk_import_dir.sh <rule.nemo> <facts_dir> <out_import_dir>" >&2
  exit 2
}

[[ $# -eq 3 ]] || usage

rule_file="$1"
facts_dir="$2"
out_import_dir="$3"

if [[ ! -f "$rule_file" ]]; then
  echo "rule not found: $rule_file" >&2
  exit 2
fi
if [[ ! -d "$facts_dir" ]]; then
  echo "facts_dir not found: $facts_dir" >&2
  exit 2
fi
if [[ -z "$out_import_dir" || "$out_import_dir" == "/" ]]; then
  echo "refusing unsafe out_import_dir: $out_import_dir" >&2
  exit 2
fi

mkdir -p "$out_import_dir"

extract_import_resources() {
  awk '
    function flush_statement(    resource) {
      if (statement ~ /^[[:space:]]*@import[[:space:]]/ && match(statement, /resource[[:space:]]*=[[:space:]]*"[^"]+"/)) {
        resource = substr(statement, RSTART, RLENGTH)
        sub(/^[^"]*"/, "", resource)
        sub(/"[[:space:]]*$/, "", resource)
        print resource
      }
      statement = ""
      collecting = 0
    }
    {
      line = $0
      if (!collecting) {
        if (line ~ /^[[:space:]]*@import[[:space:]]/) {
          statement = line
          collecting = 1
          if (line ~ /\.[[:space:]]*$/) {
            flush_statement()
          }
        }
      } else {
        statement = statement " " line
        if (line ~ /\.[[:space:]]*$/) {
          flush_statement()
        }
      }
    }
    END {
      if (collecting) {
        flush_statement()
      }
    }
  ' "$rule_file" | awk '!seen[$0]++'
}

while IFS= read -r resource; do
  [[ -n "$resource" ]] || continue
  src="$facts_dir/$resource"
  dst="$out_import_dir/$resource"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst"
  else
    : > "$dst"
  fi
done < <(extract_import_resources)
