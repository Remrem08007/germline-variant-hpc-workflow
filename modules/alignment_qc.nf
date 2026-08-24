process ALIGNMENT_QC {
    tag "${meta.id}"
    label 'small'
    publishDir { "${params.outdir}/qc/alignment/${meta.id}" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.flagstat.txt"), path("${meta.id}.samtools.stats.txt"), emit: reports

    script:
    """
    set -euo pipefail
    samtools flagstat -@ ${task.cpus} ${bam} > ${meta.id}.flagstat.txt
    samtools stats -@ ${task.cpus} ${bam} > ${meta.id}.samtools.stats.txt
    """

    stub:
    """
    echo '0 + 0 in total (QC-passed reads + QC-failed reads)' > ${meta.id}.flagstat.txt
    echo 'SN\traw total sequences:\t0' > ${meta.id}.samtools.stats.txt
    """
}
