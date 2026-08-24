process GENOTYPE_GVCF {
    tag "${meta.id}"
    label 'gatk'
    publishDir { "${params.outdir}/variants/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(gvcf), path(gvcf_tbi)
    path ref_files
    val ref_name
    path intervals
    val use_intervals
    output:
    tuple val(meta), path("${meta.id}.raw.vcf.gz"), path("${meta.id}.raw.vcf.gz.tbi"), emit: vcf
    script:
    def intArg = use_intervals ? "-L ${intervals}" : ''
    """
    gatk --java-options "-Xmx${task.memory.toGiga() - 1}g" GenotypeGVCFs \\
      -R ${ref_name} -V ${gvcf} ${intArg} \\
      -O ${meta.id}.raw.vcf.gz
    [[ -f ${meta.id}.raw.vcf.gz.tbi ]] || gatk IndexFeatureFile -I ${meta.id}.raw.vcf.gz
    """
    stub:
    """
    touch ${meta.id}.raw.vcf.gz ${meta.id}.raw.vcf.gz.tbi
    """
}
