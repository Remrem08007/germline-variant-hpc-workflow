# Germline Variant HPC Workflow

A generic **Nextflow DSL2** workflow for paired-end short-read germline variant discovery on HPC systems.

The workflow takes paired FASTQ files through preprocessing, BWA-MEM2 alignment, duplicate marking, optional base-quality score recalibration (BQSR), GATK HaplotypeCaller in GVCF mode, genotyping, hard filtering, and variant-level QC.

The project is intentionally site- and study-agnostic: no scheduler account, cluster path, cohort naming scheme, private reference layout, or study-specific interpretation logic is hard-coded.

## Workflow

```text
paired FASTQ
    |
    +-- FastQC
    |
    +-- fastp
          |
          v
      BWA-MEM2
          |
      samtools sort/index
          |
      GATK MarkDuplicates
          |
          +-- samtools flagstat/stats
          |
          +-- optional BaseRecalibrator + ApplyBQSR
          |
          v
      HaplotypeCaller -ERC GVCF
          |
          v
      GenotypeGVCFs
          |
          +-- SelectVariants SNP / INDEL
          +-- VariantFiltration
          +-- MergeVcfs
          |
          v
      bcftools stats
```

## Design choices

- paired-end FASTQ input with explicit read groups;
- BWA-MEM2 alignment;
- coordinate-sorted, indexed BAMs;
- duplicate marking before variant calling;
- alignment QC with `samtools flagstat` and `samtools stats`;
- BQSR supported with one or more known-sites VCFs and explicitly skippable when inappropriate;
- HaplotypeCaller emits per-sample GVCFs, preserving a scalable path to later cohort joint genotyping;
- `GenotypeGVCFs` produces genotyped per-sample VCFs that are then filtered;
- SNP and INDEL hard filters are applied separately with configurable expressions;
- all analysis tools run from pre-staged Apptainer/Singularity images;
- `local` and `slurm` execution profiles;
- deterministic synthetic diploid fixture with known heterozygous SNPs and an insertion;
- deterministic CI/stub execution plus a biological smoke-test validator.

GATK documents HaplotypeCaller GVCF mode as the standard scalable germline calling model. The per-sample GVCFs produced here can later be combined with GenomicsDBImport/GenotypeGVCFs for cohort-scale joint genotyping.

## Requirements

- Nextflow `>=24.04.0`
- Apptainer or Singularity
- SLURM for `-profile slurm`
- paired FASTQs
- reference FASTA with:
  - `.fai`
  - sequence dictionary (`.dict`)
  - BWA-MEM2 index files
- known-sites VCF(s) plus indexes when BQSR is enabled
- pre-staged containers listed in `assets/containers.tsv`

## Samplesheet

```csv
sample,fastq_1,fastq_2,library,platform
sample01,/data/sample01_R1.fastq.gz,/data/sample01_R2.fastq.gz,lib1,ILLUMINA
sample02,/data/sample02_R1.fastq.gz,/data/sample02_R2.fastq.gz,lib2,ILLUMINA
```

`library` and `platform` may be left blank; they default to the sample ID and `ILLUMINA`.

Validate it with:

```bash
python3 bin/validate_samplesheet.py --input samplesheet.csv
```

## Provision containers

Run from a host with registry access:

```bash
bash scripts/pull_containers.sh --output-dir /shared/germline/containers
```

Analysis jobs use only the resulting local `.sif` files.

## Run

```bash
bash scripts/run_pipeline.sh \
  --input /path/to/samplesheet.csv \
  --reference /shared/reference/GRCh38.fa \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-run \
  --profile slurm \
  --known-sites /shared/reference/dbsnp.vcf.gz,/shared/reference/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
```

For a dataset where BQSR is intentionally omitted:

```bash
bash scripts/run_pipeline.sh ... --skip-bqsr
```

Optional interval restriction for WES/targeted calling:

```bash
bash scripts/run_pipeline.sh ... --intervals /shared/reference/exome_targets.interval_list
```

## Synthetic biological fixture

The repository includes a complete small diploid test dataset:

```text
tests/fixtures/synthetic-diploid/
├── reference.fa
├── reference.fa.fai
├── reference.dict
├── truth.vcf
├── known_sites.vcf
├── sample_R1.fastq.gz
├── sample_R2.fastq.gz
└── samplesheet.csv
```

It contains two heterozygous SNPs and one heterozygous 2-bp insertion on a deterministic synthetic chromosome. The fixture is designed to validate workflow behavior, not benchmark clinical accuracy.

Run the complete synthetic smoke test after provisioning the containers:

```bash
bash scripts/run_biological_test.sh \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-smoke-test \
  --profile slurm
```

The runner builds any missing BWA-MEM2 indexes for the synthetic reference, skips BQSR (which is not meaningful for this tiny fixture), runs the normal workflow, and checks recovery of all three truth variants and their heterozygous genotypes. A successful run ends with `BIOLOGICAL TEST: PASS`.

To keep the Nextflow controller itself under SLURM:

```bash
sbatch scripts/submit_biological_test.sbatch \
  --container-dir /shared/germline/containers \
  --outdir /shared/results/germline-smoke-test \
  --profile slurm
```

Regenerate the committed fixture with `python3 bin/generate_test_fixture.py --output-dir <dir>`. The committed FASTQs are verified byte-for-byte against this generator in the Python test suite.

See `docs/testing.md`.

## Hard-filter defaults

The defaults below are transparent starting points derived from commonly used GATK hard-filter recommendations, not universal biological truth. Every threshold is exposed as a Nextflow parameter and can be overridden from an additional config. The pipeline labels failing records; it does not silently delete them.

SNP filters:

```text
QD < 2.0
SOR > 3.0
FS > 60.0
MQ < 40.0
MQRankSum < -12.5
ReadPosRankSum < -8.0
```

INDEL filters:

```text
QD < 2.0
FS > 200.0
SOR > 10.0
ReadPosRankSum < -20.0
```

For callsets with enough variants and appropriate training resources, VQSR can be preferable to fixed hard filtering. VQSR is intentionally outside v0.1 rather than silently applying cohort-inappropriate resources. This version performs per-sample genotyping; cohort joint genotyping is a deliberate future extension, while the emitted GVCFs preserve that path.

## Outputs

```text
results/
├── qc/
│   ├── fastqc/<sample>/
│   ├── fastp/<sample>/
│   └── alignment/<sample>/
├── alignment/<sample>/
│   ├── *.sorted.bam
│   └── *.sorted.bam.bai
├── duplicates/<sample>/
│   ├── *.dedup.bam
│   ├── *.dedup.bam.bai
│   └── *.markdup.metrics.txt
├── bqsr/<sample>/
│   ├── *.recal.table
│   ├── *.recal.bam
│   └── *.recal.bam.bai
├── gvcf/<sample>/*.g.vcf.gz
├── variants/<sample>/
│   ├── *.raw.vcf.gz
│   ├── *.filtered.vcf.gz
│   └── *.bcftools.stats.txt
└── pipeline_info/
```

When BQSR is skipped, HaplotypeCaller consumes the duplicate-marked BAM directly.

## Restricted-network HPC

The analysis DAG does not download containers, references, or known-sites resources. Provision them before submitting compute work. The runner disables Nextflow's nonessential latest-version check by default to avoid outbound-HTTPS timeouts on restricted compute nodes.

See `docs/offline-hpc.md`.

## Scope

This repository performs germline short-variant discovery and technical QC. It does **not** provide clinical interpretation, pathogenicity classification, phenotype prioritization, somatic calling, or diagnostic conclusions.
