process MARK_DUPLICATES {
    tag "${meta.id}"
    label 'medium'
    publishDir { "${params.outdir}/duplicates/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(bam), path(bai)
    output:
    tuple val(meta), path("${meta.id}.dedup.bam"), path("${meta.id}.dedup.bam.bai"), emit: bam
    tuple val(meta), path("${meta.id}.markdup.metrics.txt"), emit: metrics
    script:
    """
    gatk --java-options "-Xmx${task.memory.toGiga() - 1}g" MarkDuplicates \\
      -I ${bam} \\
      -O ${meta.id}.dedup.bam \\
      -M ${meta.id}.markdup.metrics.txt \\
      --CREATE_INDEX false \\
      --VALIDATION_STRINGENCY SILENT
    gatk BuildBamIndex -I ${meta.id}.dedup.bam -O ${meta.id}.dedup.bam.bai
    """
    stub:
    """
    touch ${meta.id}.dedup.bam ${meta.id}.dedup.bam.bai ${meta.id}.markdup.metrics.txt
    """
}
