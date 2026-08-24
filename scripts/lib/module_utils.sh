#!/usr/bin/env bash
set -euo pipefail
try_module_load() {
  local exe=$1 module_name=$2
  command -v "$exe" >/dev/null 2>&1 && return 0
  if type module >/dev/null 2>&1; then
    echo "$exe not found on PATH; trying: module load $module_name" >&2
    module load "$module_name" || true
  fi
  command -v "$exe" >/dev/null 2>&1
}
