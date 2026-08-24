#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/module_utils.sh
source "$REPO_ROOT/scripts/lib/module_utils.sh"

INPUT=""
REFERENCE=""
CONTAINER_DIR=""
OUTDIR=""
PROFILE="local"
ENGINE="auto"
INTERVALS=""
KNOWN_SITES=""
SKIP_BQSR=0
CONFIG=""
WORKDIR=""

usage() {
    cat <<'EOF'
Usage:
  run_pipeline.sh \
    --input CSV \
    --reference FASTA \
    --container-dir DIR \
    --outdir DIR \
    [--profile local|slurm] \
    [--engine auto|apptainer|singularity] \
    [--known-sites a.vcf.gz,b.vcf.gz | --skip-bqsr] \
    [--intervals FILE] \
    [--config FILE] \
    [--work-dir DIR]
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            INPUT=$2
            shift 2
            ;;
        --reference)
            REFERENCE=$2
            shift 2
            ;;
        --container-dir)
            CONTAINER_DIR=$2
            shift 2
            ;;
        --outdir)
            OUTDIR=$2
            shift 2
            ;;
        --profile)
            PROFILE=$2
            shift 2
            ;;
        --engine)
            ENGINE=$2
            shift 2
            ;;
        --known-sites)
            KNOWN_SITES=$2
            shift 2
            ;;
        --skip-bqsr)
            SKIP_BQSR=1
            shift
            ;;
        --intervals)
            INTERVALS=$2
            shift 2
            ;;
        --config)
            CONFIG=$2
            shift 2
            ;;
        --work-dir)
            WORKDIR=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ -n "$INPUT" ]] || { echo "--input is required" >&2; exit 2; }
[[ -n "$REFERENCE" ]] || { echo "--reference is required" >&2; exit 2; }
[[ -n "$CONTAINER_DIR" ]] || { echo "--container-dir is required" >&2; exit 2; }
[[ -n "$OUTDIR" ]] || { echo "--outdir is required" >&2; exit 2; }

case "$PROFILE" in
    local|slurm) ;;
    *)
        echo "--profile must be local or slurm" >&2
        exit 2
        ;;
esac

if [[ $SKIP_BQSR -eq 0 && -z "$KNOWN_SITES" ]]; then
    echo "--known-sites is required unless --skip-bqsr is set" >&2
    exit 2
fi
if [[ $SKIP_BQSR -eq 1 && -n "$KNOWN_SITES" ]]; then
    echo "Use either --known-sites or --skip-bqsr, not both" >&2
    exit 2
fi

INPUT=$(realpath "$INPUT")
REFERENCE=$(realpath "$REFERENCE")
CONTAINER_DIR=$(realpath "$CONTAINER_DIR")
OUTDIR=$(realpath -m "$OUTDIR")
mkdir -p "$OUTDIR"

if [[ -n "$INTERVALS" ]]; then
    INTERVALS=$(realpath "$INTERVALS")
fi
if [[ -n "$CONFIG" ]]; then
    CONFIG=$(realpath "$CONFIG")
fi
if [[ -n "$WORKDIR" ]]; then
    WORKDIR=$(realpath -m "$WORKDIR")
    mkdir -p "$WORKDIR"
fi
if [[ -n "$KNOWN_SITES" ]]; then
    IFS=, read -r -a SITE_PATHS <<< "$KNOWN_SITES"
    RESOLVED_SITES=()
    for site in "${SITE_PATHS[@]}"; do
        RESOLVED_SITES+=("$(realpath "$site")")
    done
    KNOWN_SITES=$(IFS=,; echo "${RESOLVED_SITES[*]}")
fi

python3 "$REPO_ROOT/bin/validate_samplesheet.py" --input "$INPUT"

VERIFY=(
    "$REPO_ROOT/scripts/verify_assets.sh"
    --container-dir "$CONTAINER_DIR"
    --reference "$REFERENCE"
)
if [[ $SKIP_BQSR -eq 1 ]]; then
    VERIFY+=(--skip-bqsr)
else
    VERIFY+=(--known-sites "$KNOWN_SITES")
fi
"${VERIFY[@]}"

try_module_load nextflow nextflow || {
    echo "Nextflow is unavailable" >&2
    exit 1
}

case "$ENGINE" in
    auto)
        if try_module_load apptainer apptainer; then
            ENGINE="apptainer"
        elif try_module_load singularity singularity; then
            ENGINE="singularity"
        else
            echo "Neither Apptainer nor Singularity is available" >&2
            exit 1
        fi
        ;;
    apptainer)
        try_module_load apptainer apptainer || {
            echo "Apptainer is unavailable" >&2
            exit 1
        }
        ;;
    singularity)
        try_module_load singularity singularity || {
            echo "Singularity is unavailable" >&2
            exit 1
        }
        ;;
    *)
        echo "--engine must be auto, apptainer, or singularity" >&2
        exit 2
        ;;
esac

export NXF_DISABLE_CHECK_LATEST="${NXF_DISABLE_CHECK_LATEST:-true}"

COMMAND=(nextflow)
if [[ -n "$CONFIG" ]]; then
    COMMAND+=(-c "$CONFIG")
fi
COMMAND+=(
    run "$REPO_ROOT/main.nf"
    -profile "$PROFILE,$ENGINE"
    -resume
    --input "$INPUT"
    --reference "$REFERENCE"
    --container_dir "$CONTAINER_DIR"
    --outdir "$OUTDIR"
)
if [[ -n "$KNOWN_SITES" ]]; then
    COMMAND+=(--known_sites "$KNOWN_SITES")
fi
if [[ $SKIP_BQSR -eq 1 ]]; then
    COMMAND+=(--skip_bqsr true)
fi
if [[ -n "$INTERVALS" ]]; then
    COMMAND+=(--intervals "$INTERVALS")
fi
if [[ -n "$WORKDIR" ]]; then
    COMMAND+=(-work-dir "$WORKDIR")
fi

printf 'Command:'
printf ' %q' "${COMMAND[@]}"
printf '\n'

"${COMMAND[@]}"
