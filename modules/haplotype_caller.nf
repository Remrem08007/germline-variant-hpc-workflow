process HAPLOTYPE_CALLER {
    tag "${meta.id}"
    label 'gatk'
    publishDir { "${params.outdir}/gvcf/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(bam), path(bai)
    path ref_files
    val ref_name
    path intervals
    val use_intervals
    output:
    tuple val(meta), path("${meta.id}.g.vcf.gz"), path("${meta.id}.g.vcf.gz.tbi"), emit: gvcf
    script:
    def intArg = use_intervals ? "-L ${intervals}" : ''
    """
    gatk --java-options "-Xmx${task.memory.toGiga() - 1}g" HaplotypeCaller \\
      -R ${ref_name} -I ${bam} ${intArg} \\
      -ERC GVCF \\
      -O ${meta.id}.g.vcf.gz
    [[ -f ${meta.id}.g.vcf.gz.tbi ]] || gatk IndexFeatureFile -I ${meta.id}.g.vcf.gz
    """
    stub:
    """
    touch ${meta.id}.g.vcf.gz ${meta.id}.g.vcf.gz.tbi
    """
}
