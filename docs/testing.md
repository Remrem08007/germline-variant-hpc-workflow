# Testing and validation

The repository uses two layers.

## CI / stub layer

```bash
nextflow run main.nf -profile test -stub-run
```

This checks DSL2 wiring and output contracts without running bioinformatics tools. Python tests independently verify the samplesheet parser, synthetic fixture, and VCF validator.

## Synthetic diploid biological fixture

`tests/fixtures/synthetic-diploid/` contains a deterministic 12 kb chromosome and paired reads generated from two haplotypes. The alternate haplotype contains:

- heterozygous SNP at position 3001;
- heterozygous SNP at position 7001;
- heterozygous 2-bp insertion at position 9000.

`truth.vcf` defines the expected variants and `known_sites.vcf` is provided as a tiny fixture resource. For the smoke test, BQSR should normally be skipped because empirical recalibration is not meaningful on a tiny synthetic dataset.

The end-to-end validator checks that all truth variants are present in the final filtered VCF with the expected genotype.

This fixture is for workflow validation, not sensitivity/specificity benchmarking. A future benchmark layer can use GIAB HG002/HG001 truth sets on GRCh38.

## Run the biological smoke test

After provisioning the containers:

```bash
bash scripts/run_biological_test.sh \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-smoke-test \
  --profile slurm
```

The test runner prepares missing BWA-MEM2 indexes for the synthetic reference, invokes the normal pipeline with BQSR disabled, and then runs `bin/validate_test_run.py`. The validator requires all three truth alleles to be present in the final `*.filtered.vcf.gz` with heterozygous genotypes. It does not require each truth record to have `FILTER=PASS`, because the purpose of this tiny fixture is caller/workflow recovery rather than calibration of hard-filter annotation distributions.

## Regenerate the committed fixture

```bash
python3 bin/generate_test_fixture.py --output-dir /tmp/synthetic-diploid
```

The generator uses a fixed seed and deterministic gzip timestamps. A unit test regenerates the fixture and compares the core files byte-for-byte with the committed copies. BWA-MEM2 index files are derived runtime assets and are intentionally not committed.
