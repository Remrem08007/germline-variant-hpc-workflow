import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

from validate_samplesheet import validate  # noqa: E402


class SamplesheetTests(unittest.TestCase):
    def test_fixture_samplesheet(self):
        rows = validate(ROOT / "tests/fixtures/synthetic-diploid/samplesheet.csv")
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0][0], "synthetic")


if __name__ == "__main__":
    unittest.main()
