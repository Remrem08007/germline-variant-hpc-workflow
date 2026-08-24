process BQSR {
    tag "${meta.id}"
    label 'gatk'
    publishDir { "${params.outdir}/bqsr/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(bam), path(bai)
    path ref_files
    val ref_name
    path known_files
    path intervals
    val use_intervals
    output:
    tuple val(meta), path("${meta.id}.recal.bam"), path("${meta.id}.recal.bam.bai"), emit: bam
    tuple val(meta), path("${meta.id}.recal.table"), emit: table
    script:
    def vcfs = known_files.findAll { it.name.endsWith('.vcf') || it.name.endsWith('.vcf.gz') }
    def ks = vcfs.collect { "--known-sites ${it}" }.join(' ')
    def intArg = use_intervals ? "-L ${intervals}" : ''
    """
    gatk --java-options "-Xmx${task.memory.toGiga() - 1}g" BaseRecalibrator \\
      -R ${ref_name} -I ${bam} ${ks} ${intArg} \\
      -O ${meta.id}.recal.table
    gatk --java-options "-Xmx${task.memory.toGiga() - 1}g" ApplyBQSR \\
      -R ${ref_name} -I ${bam} \\
      --bqsr-recal-file ${meta.id}.recal.table ${intArg} \\
      -O ${meta.id}.recal.bam
    gatk BuildBamIndex -I ${meta.id}.recal.bam -O ${meta.id}.recal.bam.bai
    """
    stub:
    """
    touch ${meta.id}.recal.bam ${meta.id}.recal.bam.bai ${meta.id}.recal.table
    """
}
