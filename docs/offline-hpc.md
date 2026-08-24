# Restricted-network HPC execution

Provisioning and analysis are deliberately separated.

Before analysis, stage:

1. the repository checkout;
2. local `.sif` containers;
3. the reference FASTA, dictionary, FASTA index and BWA-MEM2 index;
4. known-sites resources if BQSR is enabled.

The analysis DAG does not pull images or download reference data. `scripts/run_pipeline.sh` also sets `NXF_DISABLE_CHECK_LATEST=true` by default to suppress Nextflow's nonessential version probe on restricted compute nodes.

No scheduler account or partition is committed. Put site-specific settings in an external config and pass it with `--config`.
