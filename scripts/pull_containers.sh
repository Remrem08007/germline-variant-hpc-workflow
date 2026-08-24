#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/module_utils.sh
source "$REPO_ROOT/scripts/lib/module_utils.sh"

OUTPUT_DIR=""
usage() { echo "Usage: $0 --output-dir DIR"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) OUTPUT_DIR=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$OUTPUT_DIR" ]] || { echo "--output-dir is required" >&2; exit 2; }
mkdir -p "$OUTPUT_DIR"
if try_module_load apptainer apptainer; then RUNTIME=apptainer
elif try_module_load singularity singularity; then RUNTIME=singularity
else echo "Neither Apptainer nor Singularity is available" >&2; exit 1; fi
while IFS=$'\t' read -r filename source; do
  [[ "$filename" == "filename" || -z "$filename" ]] && continue
  destination="$OUTPUT_DIR/$filename"
  [[ -s "$destination" ]] && { echo "exists: $destination"; continue; }
  echo "pulling $source -> $destination"
  "$RUNTIME" pull "$destination.partial" "$source"
  mv "$destination.partial" "$destination"
done < "$REPO_ROOT/assets/containers.tsv"
