process VARIANT_STATS {
    tag "${meta.id}"
    label 'tiny'
    publishDir { "${params.outdir}/variants/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(vcf), path(vcf_tbi)
    output:
    tuple val(meta), path("${meta.id}.bcftools.stats.txt"), emit: stats
    script:
    """
    bcftools stats ${vcf} > ${meta.id}.bcftools.stats.txt
    """
    stub:
    """
    echo 'SN\t0\tnumber of records:\t0' > ${meta.id}.bcftools.stats.txt
    """
}
