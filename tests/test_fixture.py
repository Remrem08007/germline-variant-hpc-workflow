import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests" / "fixtures" / "synthetic-diploid"
GENERATOR = ROOT / "bin" / "generate_test_fixture.py"

CORE_FIXTURE_FILES = (
    "reference.fa",
    "reference.fa.fai",
    "reference.dict",
    "truth.vcf",
    "known_sites.vcf",
    "sample_R1.fastq",
    "sample_R2.fastq",
    "samplesheet.csv",
    "README.md",
)


class FixtureTests(unittest.TestCase):
    def test_fixture_complete(self):
        for filename in CORE_FIXTURE_FILES:
            self.assertTrue((FIXTURE / filename).is_file(), filename)

    def test_fastq_pairs_match(self):
        read_ids = []
        for mate in (1, 2):
            with (FIXTURE / f"sample_R{mate}.fastq").open("r", encoding="utf-8") as handle:
                lines = list(handle)

            self.assertEqual(len(lines) % 4, 0)
            read_ids.append(
                [
                    lines[index]
                    .strip()
                    .removeprefix("@")
                    .removesuffix(f"/{mate}")
                    for index in range(0, len(lines), 4)
                ]
            )

        self.assertEqual(read_ids[0], read_ids[1])
        self.assertEqual(len(read_ids[0]), 60)

    def test_truth_has_two_snps_and_one_indel(self):
        records = [
            line.split("\t")
            for line in (FIXTURE / "truth.vcf").read_text(encoding="utf-8").splitlines()
            if not line.startswith("#")
        ]

        self.assertEqual(len(records), 3)
        self.assertEqual(
            sum(len(record[3]) == len(record[4]) for record in records),
            2,
        )
        self.assertEqual(
            sum(len(record[3]) != len(record[4]) for record in records),
            1,
        )

    def test_truth_reference_alleles_match_fasta(self):
        reference = "".join(
            line.strip()
            for line in (FIXTURE / "reference.fa").read_text(encoding="utf-8").splitlines()
            if not line.startswith(">")
        )
        for line in (FIXTURE / "truth.vcf").read_text(encoding="utf-8").splitlines():
            if line.startswith("#"):
                continue
            fields = line.split("\t")
            position = int(fields[1])
            ref = fields[3]
            self.assertEqual(
                reference[position - 1 : position - 1 + len(ref)],
                ref,
                line,
            )

    def test_samplesheet_portable(self):
        with (FIXTURE / "samplesheet.csv").open(
            newline="", encoding="utf-8"
        ) as handle:
            row = next(csv.DictReader(handle))

        self.assertFalse(Path(row["fastq_1"]).is_absolute())
        self.assertFalse(Path(row["fastq_2"]).is_absolute())

    def test_committed_fixture_matches_generator_byte_for_byte(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            generated = Path(tmpdir) / "fixture"
            subprocess.run(
                [
                    sys.executable,
                    str(GENERATOR),
                    "--output-dir",
                    str(generated),
                ],
                check=True,
                stdout=subprocess.DEVNULL,
            )

            for filename in CORE_FIXTURE_FILES:
                self.assertEqual(
                    (FIXTURE / filename).read_bytes(),
                    (generated / filename).read_bytes(),
                    filename,
                )


if __name__ == "__main__":
    unittest.main()
