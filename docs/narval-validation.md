# Alliance Canada Narval validation

## Result

The workflow passed an end-to-end synthetic biological validation on **Alliance Canada's Narval cluster** on **2026-08-24** using the SLURM execution profile and pre-staged Apptainer containers.

The test runner reported:

```text
BIOLOGICAL TEST: PASS
 - recovered truth variants: 3
```

## Test fixture

The committed `tests/fixtures/synthetic-diploid/` dataset is a deterministic 4 kb diploid synthetic chromosome with 60 paired fragments.

Truth variants:

| Position | REF | ALT | Type | Expected GT |
| --- | --- | --- | --- | --- |
| `chrSynthetic:1001` | A | C | SNP | 0/1 |
| `chrSynthetic:2201` | T | A | SNP | 0/1 |
| `chrSynthetic:3200` | A | ATT | 2-bp insertion | 0/1 |

BQSR was intentionally skipped for this tiny synthetic fixture.

## Observed final calls

All three truth variants were recovered in the final filtered VCF:

| Variant | FILTER | QUAL | DP | AD | AF | GT | GQ |
| --- | --- | ---: | ---: | --- | ---: | --- | ---: |
| `chrSynthetic:1001 A>C` | PASS | 379.64 | 20 | 10,10 | 0.500 | 0/1 | 99 |
| `chrSynthetic:2201 T>A` | PASS | 379.64 | 20 | 10,10 | 0.500 | 0/1 | 99 |
| `chrSynthetic:3200 A>ATT` | PASS | 382.60 | 20 | 10,10 | 0.500 | 0/1 | 99 |

The 10/10 allele depths and `AF=0.500` are consistent with the fixture's designed heterozygous balance.

## Pipeline stages exercised

The successful run produced artifacts from the major workflow stages:

- preprocessing and QC;
- BWA-MEM2 alignment;
- coordinate sorting and BAM indexing;
- duplicate marking and metrics;
- GATK HaplotypeCaller GVCF generation;
- `GenotypeGVCFs`;
- SNP/INDEL hard filtering;
- bcftools variant statistics;
- Nextflow execution report, timeline, trace, and DAG;
- truth-set validation with `bin/validate_test_run.py`.

## Scope

This result demonstrates that the repository's synthetic fixture can traverse the complete HPC workflow and recover its three engineered germline variants with the expected heterozygous genotypes.

It is **not** a clinical validation, diagnostic claim, or estimate of sensitivity/specificity on real human sequencing data.
