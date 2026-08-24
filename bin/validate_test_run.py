#!/usr/bin/env python3
"""Validate recovery of the known variants in the synthetic biological fixture."""

from __future__ import annotations

import argparse
import gzip
from pathlib import Path

VariantKey = tuple[str, int, str, str]


def read_vcf(path: Path) -> dict[VariantKey, tuple[str, str | None]]:
    """Read FILTER and GT for each simple VCF record keyed by CHROM/POS/REF/ALT."""

    opener = gzip.open if path.name.endswith(".gz") else open
    records: dict[VariantKey, tuple[str, str | None]] = {}

    with opener(path, "rt", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("#"):
                continue

            fields = line.rstrip("\n").split("\t")
            if len(fields) < 8:
                raise ValueError(f"Malformed VCF row in {path}: {line.rstrip()}")

            key: VariantKey = (
                fields[0],
                int(fields[1]),
                fields[3],
                fields[4],
            )

            genotype: str | None = None
            if len(fields) >= 10:
                format_keys = fields[8].split(":")
                sample_values = fields[9].split(":")
                if "GT" in format_keys:
                    gt_index = format_keys.index("GT")
                    if gt_index < len(sample_values):
                        genotype = sample_values[gt_index]

            records[key] = (fields[6], genotype)

    return records


def normalized_genotype(genotype: str | None) -> str | None:
    if genotype is None:
        return None
    return genotype.replace("|", "/")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--truth", required=True, type=Path)
    parser.add_argument("--sample", default="synthetic")
    args = parser.parse_args()

    result_vcf = (
        args.results
        / "variants"
        / args.sample
        / f"{args.sample}.filtered.vcf.gz"
    )
    if not result_vcf.is_file():
        raise SystemExit(f"Missing result VCF: {result_vcf}")

    truth = read_vcf(args.truth)
    calls = read_vcf(result_vcf)
    errors: list[str] = []

    for key, (_truth_filter, truth_gt) in truth.items():
        if key not in calls:
            errors.append(f"missing truth variant {key}")
            continue

        _call_filter, call_gt = calls[key]
        if (
            truth_gt is not None
            and call_gt is not None
            and normalized_genotype(truth_gt) != normalized_genotype(call_gt)
        ):
            errors.append(
                f"genotype mismatch {key}: expected {truth_gt}, observed {call_gt}"
            )

    if errors:
        print("BIOLOGICAL TEST: FAIL")
        for error in errors:
            print(f" - {error}")
        raise SystemExit(1)

    print("BIOLOGICAL TEST: PASS")
    print(f" - recovered truth variants: {len(truth)}")
    print(f" - VCF: {result_vcf}")


if __name__ == "__main__":
    main()
