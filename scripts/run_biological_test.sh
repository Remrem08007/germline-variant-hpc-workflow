#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FIXTURE="$REPO_ROOT/tests/fixtures/synthetic-diploid"
CONTAINER_DIR=""; OUTDIR=""; PROFILE="local"; ENGINE="auto"; CONFIG=""; WORKDIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --container-dir) CONTAINER_DIR=$2; shift 2 ;;
    --outdir) OUTDIR=$2; shift 2 ;;
    --profile) PROFILE=$2; shift 2 ;;
    --engine) ENGINE=$2; shift 2 ;;
    --config) CONFIG=$2; shift 2 ;;
    --work-dir) WORKDIR=$2; shift 2 ;;
    -h|--help) echo "Usage: $0 --container-dir DIR --outdir DIR [--profile local|slurm] [--engine auto|apptainer|singularity] [--config FILE] [--work-dir DIR]"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$CONTAINER_DIR" ]] || { echo "--container-dir is required" >&2; exit 2; }
[[ -n "$OUTDIR" ]] || { echo "--outdir is required" >&2; exit 2; }
"$REPO_ROOT/scripts/prepare_reference.sh" --reference "$FIXTURE/reference.fa" --container-dir "$CONTAINER_DIR" --engine "$ENGINE"
COMMAND=("$REPO_ROOT/scripts/run_pipeline.sh" --input "$FIXTURE/samplesheet.csv" --reference "$FIXTURE/reference.fa" --container-dir "$CONTAINER_DIR" --outdir "$OUTDIR" --profile "$PROFILE" --engine "$ENGINE" --skip-bqsr)
[[ -n "$CONFIG" ]] && COMMAND+=(--config "$CONFIG")
[[ -n "$WORKDIR" ]] && COMMAND+=(--work-dir "$WORKDIR")
"${COMMAND[@]}"
python3 "$REPO_ROOT/bin/validate_test_run.py" --results "$OUTDIR" --truth "$FIXTURE/truth.vcf" --sample synthetic
