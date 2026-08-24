# Germline Variant HPC Workflow

A generic **Nextflow DSL2** workflow for germline short-variant discovery from paired-end sequencing data on local or SLURM/HPC systems.

The workflow performs read QC and trimming, BWA-MEM2 alignment, duplicate marking, optional base quality score recalibration, per-sample GVCF calling with GATK HaplotypeCaller, genotyping, hard filtering, and alignment/variant QC. It is designed to keep site-specific infrastructure and study-specific interpretation outside the reusable core pipeline.

> **Status:** v0.1.0 initial implementation. The repository includes deterministic unit/fixture tests and a synthetic diploid biological test design. Full end-to-end biological validation with the real containers is the next release gate; the workflow should not yet be described as biologically validated.

## Workflow

```text
paired FASTQ
    │
    ├── FastQC
    ▼
  fastp
    ▼
BWA-MEM2
    ▼
samtools sort
    ▼
GATK MarkDuplicates
    ├── alignment QC
    ▼
optional BQSR
    ▼
GATK HaplotypeCaller -ERC GVCF
    ▼
GATK GenotypeGVCFs
    ▼
SNP / INDEL hard filtering
    ▼
variant QC / final filtered VCF
```

## Design goals

- generic paired-end germline short-variant workflow;
- GVCF-first calling model that preserves a path to later cohort joint genotyping;
- WGS, WES, or targeted interval support;
- optional BQSR rather than assuming appropriate known-sites resources exist for every use case;
- explicit and configurable hard-filter thresholds;
- local and SLURM execution profiles;
- Apptainer or Singularity with pre-pulled local images;
- restricted-network HPC support;
- no scheduler account, partition, username, institution, cohort, or private filesystem path hard-coded;
- deterministic synthetic diploid fixture with known SNP/indel truth;
- `-resume`-friendly wrappers, preflight validation, CI, and test utilities.

## Inputs

The samplesheet schema is deliberately simple:

```csv
sample,fastq_1,fastq_2
sample01,/data/sample01_R1.fastq.gz,/data/sample01_R2.fastq.gz
sample02,/data/sample02_R1.fastq.gz,/data/sample02_R2.fastq.gz
```

Relative FASTQ paths are resolved relative to the samplesheet directory. Sample IDs must be unique and may contain letters, numbers, `.`, `_`, and `-`.

Validate a samplesheet with:

```bash
python3 bin/validate_samplesheet.py --input samplesheet.csv
```

## Required analysis assets

Production analysis requires:

- Nextflow `>=24.04.0`;
- Apptainer or Singularity;
- BWA-MEM2-indexed reference FASTA;
- FASTA `.fai`;
- GATK sequence dictionary (`.dict`);
- local containers listed in `assets/containers.tsv`;
- optional known-sites VCFs (plus indexes) only when BQSR is enabled.

SLURM is additionally required for the `slurm` profile.

## 1. Pull containers

Run once from an environment with container-registry access:

```bash
CONTAINER_DIR=/shared/germline/containers

bash scripts/pull_containers.sh \
  --output-dir "$CONTAINER_DIR"
```

Analysis uses the local `.sif` files directly.

## 2. Prepare a reference

For a new reference FASTA:

```bash
bash scripts/prepare_reference.sh \
  --reference /shared/references/reference.fa \
  --container-dir /shared/germline/containers
```

The helper creates missing BWA-MEM2 indexes, the samtools FASTA index, and the GATK sequence dictionary. Existing valid sidecars are left in place.

## 3. Verify assets

```bash
bash scripts/verify_assets.sh \
  --container-dir /shared/germline/containers \
  --reference /shared/references/reference.fa
```

When BQSR is enabled, add one or more:

```bash
--known-sites /shared/references/dbsnp.vcf.gz
```

## 4. Run

```bash
bash scripts/run_pipeline.sh \
  --profile slurm \
  --engine auto \
  --input /absolute/path/samplesheet.csv \
  --reference /shared/references/reference.fa \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-run01
```

Keep the Nextflow controller off the login node with:

```bash
sbatch scripts/submit_pipeline.sbatch \
  --input /absolute/path/samplesheet.csv \
  --reference /shared/references/reference.fa \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-run01
```

No SLURM account or partition is hard-coded. Add site settings through an external config:

```bash
bash scripts/run_pipeline.sh ... --config /path/to/site.config
```

See `assets/cluster.config.example`.

## Intervals and sequencing design

The pipeline can operate genome-wide or on explicit intervals:

```bash
--intervals /shared/references/exome_targets.interval_list
```

This makes the same workflow usable for WGS, WES, and targeted test data without encoding one institution's capture kit into the pipeline.

## Optional BQSR

BQSR is disabled by default:

```text
--run_bqsr false
```

Enable it only when appropriate indexed known-sites resources are available:

```bash
bash scripts/run_pipeline.sh ... \
  --run-bqsr true \
  --known-sites /shared/references/dbsnp.vcf.gz \
  --known-sites /shared/references/Mills_and_1000G_gold_standard.indels.vcf.gz
```

The synthetic smoke test intentionally leaves BQSR disabled because empirical recalibration against a tiny artificial chromosome is not a meaningful benchmark.

## Hard filtering

v0.1 uses explicit hard filters rather than pretending that VQSR is appropriate for every dataset size. Defaults are parameters and can be overridden without editing module code.

Current SNP defaults:

```text
QD < 2.0
QUAL < 30.0
SOR > 3.0
FS > 60.0
MQ < 40.0
MQRankSum < -12.5
ReadPosRankSum < -8.0
```

Current indel defaults:

```text
QD < 2.0
QUAL < 30.0
FS > 200.0
ReadPosRankSum < -20.0
```

These filters are a transparent baseline, not a universal clinical interpretation rule. Dataset-specific recalibration, filtering optimization, annotation, and pathogenicity interpretation remain outside the generic core.

## Synthetic biological fixture

A complete deterministic diploid fixture is committed under:

```text
tests/fixtures/synthetic-diploid/
├── README.md
├── reference.fa
├── reference.fa.fai
├── reference.dict
├── known_sites.vcf
├── sample_R1.fastq.gz
├── sample_R2.fastq.gz
├── samplesheet.csv
└── truth.vcf
```

The 12 kb synthetic chromosome contains three known heterozygous variants:

```text
chrSynthetic:3001  SNP  C>A    GT 0/1
chrSynthetic:7001  SNP  C>A    GT 0/1
chrSynthetic:9000  INS  A>ATT  GT 0/1
```

The generator uses a fixed seed and deterministic gzip metadata. CI/unit tests regenerate the fixture and compare it byte-for-byte with the committed files.

Once containers are staged, the intended real smoke test is:

```bash
bash scripts/run_biological_test.sh \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-synthetic-test
```

The runner prepares any missing BWA-MEM2 reference sidecars, runs the normal pipeline on the committed fixture, and calls `bin/validate_test_run.py` against `truth.vcf`.

The release gate is:

```text
BIOLOGICAL TEST: PASS
```

Until that real run passes, this repository is an **implemented and testable v0.1 workflow**, not a claimed validated production caller.

See `docs/testing.md`.

## Outputs

The workflow publishes a structured result tree similar to:

```text
results/
├── fastqc/
├── fastp/
├── alignment/
│   ├── sorted/
│   ├── deduplicated/
│   └── qc/
├── bqsr/                     # when enabled
├── gvcf/
├── variants/
│   ├── raw/
│   └── filtered/
├── qc/
│   └── variants/
└── pipeline_info/
```

## Testing

CI runs:

- Python unit tests;
- deterministic fixture regeneration checks;
- shell syntax checks;
- Nextflow `-stub-run` to exercise the DSL2 graph and process contracts without real bioinformatics computation.

See `docs/testing.md` for the distinction between structural CI and the real biological release gate.

## Restricted-network HPC

The analysis DAG is designed to use only staged local references and containers. Provisioning is separate. The launcher suppresses Nextflow's nonessential latest-version HTTP probe by default to avoid compute-node network timeouts.

See `docs/offline-hpc.md`.

## Scope

This workflow produces research-grade germline short-variant calls and QC artifacts. It does **not** perform clinical interpretation, pathogenicity classification, pedigree/de novo inference, or study-specific cohort filtering. Those concerns intentionally remain separate so the core workflow stays reusable.

## Version

Current development version: `0.1.0`.

## License

MIT.
