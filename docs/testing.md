# Testing and validation

The repository uses two complementary validation layers.

## CI / stub layer

```bash
nextflow run main.nf -profile test -stub-run
```

This checks DSL2 wiring and output contracts without running the bioinformatics tools. Python tests independently verify the samplesheet parser, synthetic fixture, and VCF validator.

## Synthetic diploid biological fixture

`tests/fixtures/synthetic-diploid/` contains a deterministic **4 kb** chromosome and **60 paired fragments** generated from two haplotypes.

The alternate haplotype contains:

- heterozygous SNP at `chrSynthetic:1001` (`A>C`);
- heterozygous SNP at `chrSynthetic:2201` (`T>A`);
- heterozygous 2-bp insertion at `chrSynthetic:3200` (`A>ATT`).

For each truth site, the fixture contributes 10 reference-haplotype and 10 alternate-haplotype fragments. Their fragment starts are intentionally distinct across haplotypes so `MarkDuplicates` does not collapse the alternate evidence.

`truth.vcf` defines the expected variants and `known_sites.vcf` is included as a tiny fixture resource. For the smoke test, BQSR is skipped because empirical recalibration is not meaningful on this synthetic dataset.

The end-to-end validator checks that every truth allele is present in the final filtered VCF with the expected genotype. The current validator does not require `FILTER=PASS`; the recorded Narval validation run nevertheless produced `PASS` for all three truth calls.

This fixture is for workflow validation, not sensitivity/specificity benchmarking. A future benchmark layer can use GIAB truth sets on GRCh38.

## Run the biological smoke test

After provisioning the containers:

```bash
bash scripts/run_biological_test.sh \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-smoke-test \
  --profile slurm
```

On an HPC system where the Nextflow controller should also run under SLURM:

```bash
sbatch scripts/submit_biological_test.sbatch \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-smoke-test \
  --profile slurm
```

The test runner prepares missing BWA-MEM2 indexes for the synthetic reference, invokes the normal pipeline with BQSR disabled, and then runs `bin/validate_test_run.py`.

A successful run ends with:

```text
BIOLOGICAL TEST: PASS
 - recovered truth variants: 3
```

## Recorded Narval validation

An end-to-end run on **Alliance Canada's Narval cluster** using **SLURM + Apptainer** passed on **2026-08-24**.

Observed final truth calls:

| Truth variant | FILTER | DP | AD | GT | GQ |
| --- | --- | ---: | --- | --- | ---: |
| `chrSynthetic:1001 A>C` | PASS | 20 | 10,10 | 0/1 | 99 |
| `chrSynthetic:2201 T>A` | PASS | 20 | 10,10 | 0/1 | 99 |
| `chrSynthetic:3200 A>ATT` | PASS | 20 | 10,10 | 0/1 | 99 |

The run produced aligned BAMs, duplicate-marked BAMs and metrics, a per-sample GVCF, raw and filtered VCFs, bcftools statistics, and Nextflow execution report/timeline/trace/DAG artifacts.

See [`narval-validation.md`](narval-validation.md) for the recorded validation details.

## Regenerate the committed fixture

```bash
python3 bin/generate_test_fixture.py --output-dir /tmp/synthetic-diploid
```

The generator uses a fixed seed and writes deterministic plain-text FASTQs. A unit test regenerates the fixture and compares the core files byte-for-byte with the committed copies. BWA-MEM2 index files are runtime-derived assets and are intentionally not committed.
