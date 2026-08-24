#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/module_utils.sh
source "$REPO_ROOT/scripts/lib/module_utils.sh"

REFERENCE=""
CONTAINER_DIR=""
ENGINE="auto"

usage() {
    cat <<'EOF'
Usage:
  prepare_reference.sh \
    --reference FASTA \
    --container-dir DIR \
    [--engine auto|apptainer|singularity]
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reference)
            REFERENCE=$2
            shift 2
            ;;
        --container-dir)
            CONTAINER_DIR=$2
            shift 2
            ;;
        --engine)
            ENGINE=$2
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

[[ -n "$REFERENCE" ]] || { echo "--reference is required" >&2; exit 2; }
[[ -n "$CONTAINER_DIR" ]] || { echo "--container-dir is required" >&2; exit 2; }
[[ -s "$REFERENCE" ]] || { echo "Reference not found: $REFERENCE" >&2; exit 1; }

case "$ENGINE" in
    auto)
        if try_module_load apptainer apptainer; then
            RUNTIME="apptainer"
        elif try_module_load singularity singularity; then
            RUNTIME="singularity"
        else
            echo "Neither Apptainer nor Singularity is available" >&2
            exit 1
        fi
        ;;
    apptainer|singularity)
        try_module_load "$ENGINE" "$ENGINE" || {
            echo "$ENGINE is unavailable" >&2
            exit 1
        }
        RUNTIME="$ENGINE"
        ;;
    *)
        echo "--engine must be auto, apptainer, or singularity" >&2
        exit 2
        ;;
esac

for image in samtools.sif gatk.sif bwa_mem2.sif; do
    [[ -s "$CONTAINER_DIR/$image" ]] || {
        echo "Missing container: $CONTAINER_DIR/$image" >&2
        exit 1
    }
done

REFERENCE_DIR=$(cd "$(dirname "$REFERENCE")" && pwd)
REFERENCE_NAME=$(basename "$REFERENCE")
REFERENCE_STEM=${REFERENCE_NAME%.*}
REFERENCE_DICT="$REFERENCE_DIR/$REFERENCE_STEM.dict"

if [[ ! -s "$REFERENCE.fai" ]]; then
    "$RUNTIME" exec \
        --bind "$REFERENCE_DIR:$REFERENCE_DIR" \
        "$CONTAINER_DIR/samtools.sif" \
        samtools faidx "$REFERENCE"
else
    echo "exists: $REFERENCE.fai"
fi

if [[ ! -s "$REFERENCE_DICT" ]]; then
    "$RUNTIME" exec \
        --bind "$REFERENCE_DIR:$REFERENCE_DIR" \
        "$CONTAINER_DIR/gatk.sif" \
        gatk CreateSequenceDictionary \
            -R "$REFERENCE" \
            -O "$REFERENCE_DICT"
else
    echo "exists: $REFERENCE_DICT"
fi

BWA_COMPLETE=1
for suffix in .0123 .amb .ann .bwt.2bit.64 .pac; do
    if [[ ! -s "$REFERENCE$suffix" ]]; then
        BWA_COMPLETE=0
        break
    fi
done

if [[ $BWA_COMPLETE -eq 0 ]]; then
    "$RUNTIME" exec \
        --bind "$REFERENCE_DIR:$REFERENCE_DIR" \
        "$CONTAINER_DIR/bwa_mem2.sif" \
        bwa-mem2 index "$REFERENCE"
else
    echo "exists: BWA-MEM2 index for $REFERENCE"
fi

echo "Reference assets ready: $REFERENCE"
