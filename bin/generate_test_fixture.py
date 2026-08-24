#!/usr/bin/env python3
"""Generate the deterministic synthetic diploid fixture used by this repository."""

from __future__ import annotations

import argparse
import gzip
import random
from pathlib import Path

DNA = "ACGT"
REFERENCE_NAME = "chrSynthetic"
REFERENCE_LENGTH = 12_000
READ_LENGTH = 150
FRAGMENT_LENGTH = 350
STEP = 20
DEFAULT_SEED = 20260824


def reverse_complement(sequence: str) -> str:
    return sequence.translate(str.maketrans("ACGT", "TGCA"))[::-1]


def write_fasta(path: Path, sequence: str) -> None:
    with path.open("w", encoding="utf-8") as handle:
        handle.write(f">{REFERENCE_NAME}\n")
        for start in range(0, len(sequence), 60):
            handle.write(sequence[start : start + 60] + "\n")


def write_fastq_gz(path: Path, records: list[tuple[str, str]], mate: int) -> None:
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
            for name, sequence in records:
                payload = (
                    f"@{name}/{mate}\n{sequence}\n+\n{'I' * len(sequence)}\n"
                ).encode()
                gz.write(payload)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate deterministic synthetic diploid germline test data."
    )
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    args = parser.parse_args()

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)

    reference = "".join(rng.choice(DNA) for _ in range(REFERENCE_LENGTH))
    alternate = list(reference)
    variants: list[tuple[int, str, str]] = []

    for position in (3001, 7001):
        ref_base = reference[position - 1]
        alt_base = next(base for base in DNA if base != ref_base)
        alternate[position - 1] = alt_base
        variants.append((position, ref_base, alt_base))

    alternate_sequence = "".join(alternate)

    insertion_position = 9000
    insertion_sequence = "TT"
    anchor_base = reference[insertion_position - 1]
    alternate_sequence = (
        alternate_sequence[:insertion_position]
        + insertion_sequence
        + alternate_sequence[insertion_position:]
    )
    variants.append(
        (insertion_position, anchor_base, anchor_base + insertion_sequence)
    )

    write_fasta(output_dir / "reference.fa", reference)
    (output_dir / "reference.fa.fai").write_text(
        f"{REFERENCE_NAME}\t{REFERENCE_LENGTH}\t14\t60\t61\n",
        encoding="utf-8",
    )
    (output_dir / "reference.dict").write_text(
        "@HD\tVN:1.6\tSO:unsorted\n"
        f"@SQ\tSN:{REFERENCE_NAME}\tLN:{REFERENCE_LENGTH}\n",
        encoding="utf-8",
    )

    vcf_header = (
        "##fileformat=VCFv4.2\n"
        f"##contig=<ID={REFERENCE_NAME},length={REFERENCE_LENGTH}>\n"
        '##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">\n'
        "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tsynthetic\n"
    )
    vcf_body = "".join(
        f"{REFERENCE_NAME}\t{position}\t.\t{ref}\t{alt}\t100\tPASS\t.\tGT\t0/1\n"
        for position, ref, alt in variants
    )
    for filename in ("truth.vcf", "known_sites.vcf"):
        (output_dir / filename).write_text(vcf_header + vcf_body, encoding="utf-8")

    pairs: list[tuple[str, str, str]] = []
    serial = 0
    for reference_start in range(0, REFERENCE_LENGTH - FRAGMENT_LENGTH, STEP):
        for haplotype, haplotype_sequence in ((0, reference), (1, alternate_sequence)):
            serial += 1
            haplotype_start = reference_start
            if haplotype == 1 and reference_start >= insertion_position:
                haplotype_start += len(insertion_sequence)
            fragment = haplotype_sequence[haplotype_start : haplotype_start + FRAGMENT_LENGTH]
            if len(fragment) != FRAGMENT_LENGTH:
                continue
            name = f"synthetic.{serial:05d}.h{haplotype}"
            read1 = fragment[:READ_LENGTH]
            read2 = reverse_complement(fragment[-READ_LENGTH:])
            pairs.append((name, read1, read2))

    rng.shuffle(pairs)
    write_fastq_gz(output_dir / "sample_R1.fastq.gz", [(name, read1) for name, read1, _ in pairs], mate=1)
    write_fastq_gz(output_dir / "sample_R2.fastq.gz", [(name, read2) for name, _, read2 in pairs], mate=2)
    (output_dir / "samplesheet.csv").write_text(
        "sample,fastq_1,fastq_2,library,platform\n"
        "synthetic,sample_R1.fastq.gz,sample_R2.fastq.gz,synthetic-lib,ILLUMINA\n",
        encoding="utf-8",
    )
    (output_dir / "README.md").write_text(
        "# Synthetic diploid fixture\n\n"
        f"Deterministic 12 kb diploid fixture with {len(pairs)} paired fragments.\n\n"
        "Truth: two heterozygous SNPs and one heterozygous 2-bp insertion.\n",
        encoding="utf-8",
    )
    print(output_dir)


if __name__ == "__main__":
    main()
