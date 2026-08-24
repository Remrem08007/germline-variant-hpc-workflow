#!/usr/bin/env bash
#SBATCH --job-name=germline-test
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=24:00:00
#SBATCH --output=germline-test-%j.out
set -euo pipefail
REPO_ROOT="${GERMLINE_REPO_ROOT:-${SLURM_SUBMIT_DIR:-$PWD}}"
if [[ ! -f "$REPO_ROOT/main.nf" && -f "$REPO_ROOT/../main.nf" ]]; then REPO_ROOT=$(cd "$REPO_ROOT/.." && pwd); fi
[[ -f "$REPO_ROOT/main.nf" ]] || { echo "Could not resolve repository root" >&2; exit 1; }
exec "$REPO_ROOT/scripts/run_biological_test.sh" "$@"
