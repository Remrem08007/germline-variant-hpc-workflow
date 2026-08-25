#!/usr/bin/env python3
"""Generate the deterministic synthetic diploid fixture used by this repository."""

from __future__ import annotations

import argparse
import random
from pathlib import Path

DNA = "ACGT"
REFERENCE_NAME = "chrSynthetic"
REFERENCE_LENGTH = 4_000
READ_LENGTH = 150
FRAGMENT_LENGTH = 350
DEFAULT_SEED = 20260824
TRUTH_POSITIONS = (1001, 2201, 3200)
FRAGMENTS_PER_HAPLOTYPE_PER_SITE = 10


def reverse_complement(sequence: str) -> str:
    return sequence.translate(str.maketrans("ACGT", "TGCA"))[::-1]


def write_fasta(path: Path, sequence: str) -> None:
    with path.open("w", encoding="utf-8") as handle:
        handle.write(f">{REFERENCE_NAME}\n")
        for start in range(0, len(sequence), 60):
            handle.write(sequence[start : start + 60] + "\n")


def write_fastq(
    path: Path,
    records: list[tuple[str, str]],
    mate: int,
) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for name, sequence in records:
            handle.write(
                f"@{name}/{mate}\n"
                f"{sequence}\n"
                "+\n"
                f"{'I' * len(sequence)}\n"
            )


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

    for position in TRUTH_POSITIONS[:2]:
        ref_base = reference[position - 1]
        alt_base = next(base for base in DNA if base != ref_base)
        alternate[position - 1] = alt_base
        variants.append((position, ref_base, alt_base))

    alternate_sequence = "".join(alternate)

    insertion_position = TRUTH_POSITIONS[2]
    insertion_sequence = "TT"
    anchor_base = reference[insertion_position - 1]
    alternate_sequence = (
        alternate_sequence[:insertion_position]
        + insertion_sequence
        + alternate_sequence[insertion_position:]
    )
    variants.append(
        (
            insertion_position,
            anchor_base,
            anchor_base + insertion_sequence,
        )
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
        (output_dir / filename).write_text(
            vcf_header + vcf_body,
            encoding="utf-8",
        )

    pairs: list[tuple[str, str, str]] = []
    serial = 0

    for variant_position in TRUTH_POSITIONS:
        for haplotype in (0, 1):
            haplotype_sequence = (
                reference if haplotype == 0 else alternate_sequence
            )

            for offset in range(FRAGMENTS_PER_HAPLOTYPE_PER_SITE):
                serial += 1

                # Keep reference- and alternate-haplotype fragment starts distinct.
                # This prevents MarkDuplicates from collapsing the synthetic
                # alternate evidence while retaining balanced 10/10 coverage.
                start_1based = (
                    variant_position
                    - 110
                    + haplotype * FRAGMENTS_PER_HAPLOTYPE_PER_SITE
                    + offset
                )
                start = start_1based - 1
                fragment = haplotype_sequence[start : start + FRAGMENT_LENGTH]

                if len(fragment) != FRAGMENT_LENGTH:
                    raise RuntimeError(
                        f"Short synthetic fragment at {variant_position}: "
                        f"{len(fragment)} bp"
                    )

                name = f"synthetic.{serial:04d}.h{haplotype}"
                read1 = fragment[:READ_LENGTH]
                read2 = reverse_complement(fragment[-READ_LENGTH:])
                pairs.append((name, read1, read2))

    rng.shuffle(pairs)

    write_fastq(
        output_dir / "sample_R1.fastq",
        [(name, read1) for name, read1, _ in pairs],
        mate=1,
    )
    write_fastq(
        output_dir / "sample_R2.fastq",
        [(name, read2) for name, _, read2 in pairs],
        mate=2,
    )
    (output_dir / "samplesheet.csv").write_text(
        "sample,fastq_1,fastq_2,library,platform\n"
        "synthetic,sample_R1.fastq,sample_R2.fastq,synthetic-lib,ILLUMINA\n",
        encoding="utf-8",
    )
    (output_dir / "README.md").write_text(
        "# Synthetic diploid fixture\n\n"
        "Deterministic 4 kb diploid fixture with 60 paired fragments.\n\n"
        "Truth: two heterozygous SNPs and one heterozygous 2-bp insertion.\n",
        encoding="utf-8",
    )

    print(output_dir)


if __name__ == "__main__":
    main()
