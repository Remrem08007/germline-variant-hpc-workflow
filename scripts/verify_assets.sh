#!/usr/bin/env bash
set -euo pipefail

CONTAINER_DIR=""
REFERENCE=""
KNOWN_SITES=""
SKIP_BQSR=0

usage() {
    cat <<'EOF'
Usage:
  verify_assets.sh \
    --container-dir DIR \
    --reference FASTA \
    [--known-sites a.vcf.gz,b.vcf.gz | --skip-bqsr]
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container-dir)
            CONTAINER_DIR=$2
            shift 2
            ;;
        --reference)
            REFERENCE=$2
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

[[ -n "$CONTAINER_DIR" ]] || { echo "--container-dir is required" >&2; exit 2; }
[[ -n "$REFERENCE" ]] || { echo "--reference is required" >&2; exit 2; }

for filename in \
    fastqc.sif \
    fastp.sif \
    bwa_mem2.sif \
    samtools.sif \
    gatk.sif \
    bcftools.sif; do
    [[ -s "$CONTAINER_DIR/$filename" ]] || {
        echo "Missing container: $CONTAINER_DIR/$filename" >&2
        exit 1
    }
done

[[ -s "$REFERENCE" ]] || { echo "Missing reference: $REFERENCE" >&2; exit 1; }
[[ -s "$REFERENCE.fai" ]] || {
    echo "Missing reference FASTA index: $REFERENCE.fai" >&2
    exit 1
}

REFERENCE_DICT="${REFERENCE%.*}.dict"
[[ -s "$REFERENCE_DICT" ]] || {
    echo "Missing reference dictionary: $REFERENCE_DICT" >&2
    exit 1
}

for suffix in .0123 .amb .ann .bwt.2bit.64 .pac; do
    [[ -s "$REFERENCE$suffix" ]] || {
        echo "Missing BWA-MEM2 index: $REFERENCE$suffix" >&2
        exit 1
    }
done

if [[ $SKIP_BQSR -eq 0 ]]; then
    [[ -n "$KNOWN_SITES" ]] || {
        echo "--known-sites is required unless --skip-bqsr is set" >&2
        exit 1
    }

    IFS=',' read -r -a SITES <<< "$KNOWN_SITES"
    for site in "${SITES[@]}"; do
        [[ -s "$site" ]] || {
            echo "Missing known-sites VCF: $site" >&2
            exit 1
        }
        if [[ ! -s "$site.tbi" && ! -s "$site.idx" ]]; then
            echo "Missing known-sites VCF index for: $site" >&2
            exit 1
        fi
    done
fi

echo "All required assets are present."
