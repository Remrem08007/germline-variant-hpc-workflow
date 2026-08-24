#!/usr/bin/env python3
"""Validate the paired-end samplesheet used by the workflow."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

SAMPLE_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
REQUIRED_COLUMNS = ("sample", "fastq_1", "fastq_2")


def validate(
    path: Path,
    check_files: bool = True,
) -> list[tuple[str, Path, Path, str, str]]:
    """Validate a samplesheet and return resolved sample records."""

    path = path.resolve()
    if not path.is_file():
        raise ValueError(f"Samplesheet not found: {path}")

    records: list[tuple[str, Path, Path, str, str]] = []
    seen_samples: set[str] = set()

    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError("Samplesheet is empty")

        missing = [
            column for column in REQUIRED_COLUMNS if column not in reader.fieldnames
        ]
        if missing:
            raise ValueError(
                f"Missing samplesheet column(s): {', '.join(missing)}"
            )

        for line_number, row in enumerate(reader, start=2):
            sample = (row.get("sample") or "").strip()
            read1_raw = (row.get("fastq_1") or "").strip()
            read2_raw = (row.get("fastq_2") or "").strip()

            if not sample or not read1_raw or not read2_raw:
                raise ValueError(
                    f"Line {line_number}: sample, fastq_1 and fastq_2 are required"
                )
            if not SAMPLE_RE.fullmatch(sample):
                raise ValueError(
                    f"Line {line_number}: invalid sample '{sample}'; use letters, "
                    "numbers, '.', '_' or '-'"
                )
            if sample in seen_samples:
                raise ValueError(
                    f"Line {line_number}: duplicate sample '{sample}'"
                )
            seen_samples.add(sample)

            read1 = Path(read1_raw)
            read2 = Path(read2_raw)
            if not read1.is_absolute():
                read1 = (path.parent / read1).resolve()
            if not read2.is_absolute():
                read2 = (path.parent / read2).resolve()

            if check_files:
                if not read1.is_file():
                    raise ValueError(
                        f"Line {line_number}: FASTQ not found: {read1}"
                    )
                if not read2.is_file():
                    raise ValueError(
                        f"Line {line_number}: FASTQ not found: {read2}"
                    )

            library = (row.get("library") or sample).strip() or sample
            platform = (row.get("platform") or "ILLUMINA").strip() or "ILLUMINA"
            records.append((sample, read1, read2, library, platform))

    if not records:
        raise ValueError("Samplesheet contains no samples")

    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--no-check-files", action="store_true")
    args = parser.parse_args()

    records = validate(args.input, check_files=not args.no_check_files)
    print(f"Samplesheet OK: {len(records)} sample(s)")


if __name__ == "__main__":
    main()
