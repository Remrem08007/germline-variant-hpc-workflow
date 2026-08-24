process SORT_BAM {
    tag "${meta.id}"
    label 'medium'
    publishDir { "${params.outdir}/alignment/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(sam)
    output:
    tuple val(meta), path("${meta.id}.sorted.bam"), path("${meta.id}.sorted.bam.bai"), emit: bam
    script:
    """
    set -euo pipefail
    samtools sort -@ ${task.cpus} -m ${params.samtools_sort_mem} -o ${meta.id}.sorted.bam ${sam}
    samtools index -@ ${task.cpus} ${meta.id}.sorted.bam
    """
    stub:
    """
    touch ${meta.id}.sorted.bam ${meta.id}.sorted.bam.bai
    """
}
