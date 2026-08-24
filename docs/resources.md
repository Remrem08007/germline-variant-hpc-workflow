# Resource model

Default SLURM resources are conservative starting points and should be tuned for read depth, genome size, intervals and cluster hardware.

| Process class | CPUs | Memory | Time |
| --- | ---: | ---: | ---: |
| tiny | 1 | 2 GB | 1 h |
| small | 2 | 6 GB | 4 h |
| medium | 4 | 16 GB | 8 h |
| alignment | 16 | 24 GB | 24 h |
| GATK | 4 | 16 GB | 24 h |

For whole-genome production workloads, alignment, duplicate marking and HaplotypeCaller are the main tuning targets. Use an external site config to override resources.
