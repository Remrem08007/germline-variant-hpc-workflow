process HARD_FILTER {
    tag "${meta.id}"
    label 'gatk'
    publishDir { "${params.outdir}/variants/${meta.id}" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(vcf), path(vcf_tbi)
    path ref_files
    val ref_name

    output:
    tuple val(meta), path("${meta.id}.filtered.vcf.gz"), path("${meta.id}.filtered.vcf.gz.tbi"), emit: vcf

    script:
    """
    set -euo pipefail

    gatk SelectVariants \
      -R ${ref_name} \
      -V ${vcf} \
      --select-type-to-include SNP \
      -O ${meta.id}.snps.vcf.gz

    gatk VariantFiltration \
      -R ${ref_name} \
      -V ${meta.id}.snps.vcf.gz \
      --filter-name QD \
      --filter-expression 'QD < ${params.snp_qd_min}' \
      --filter-name SOR \
      --filter-expression 'SOR > ${params.snp_sor_max}' \
      --filter-name FS \
      --filter-expression 'FS > ${params.snp_fs_max}' \
      --filter-name MQ \
      --filter-expression 'MQ < ${params.snp_mq_min}' \
      --filter-name MQRankSum \
      --filter-expression 'MQRankSum < ${params.snp_mq_rank_sum_min}' \
      --filter-name ReadPosRankSum \
      --filter-expression 'ReadPosRankSum < ${params.snp_read_pos_rank_sum_min}' \
      -O ${meta.id}.snps.filtered.vcf.gz

    gatk SelectVariants \
      -R ${ref_name} \
      -V ${vcf} \
      --select-type-to-include INDEL \
      -O ${meta.id}.indels.vcf.gz

    gatk VariantFiltration \
      -R ${ref_name} \
      -V ${meta.id}.indels.vcf.gz \
      --filter-name QD \
      --filter-expression 'QD < ${params.indel_qd_min}' \
      --filter-name FS \
      --filter-expression 'FS > ${params.indel_fs_max}' \
      --filter-name SOR \
      --filter-expression 'SOR > ${params.indel_sor_max}' \
      --filter-name ReadPosRankSum \
      --filter-expression 'ReadPosRankSum < ${params.indel_read_pos_rank_sum_min}' \
      -O ${meta.id}.indels.filtered.vcf.gz

    gatk MergeVcfs \
      -I ${meta.id}.snps.filtered.vcf.gz \
      -I ${meta.id}.indels.filtered.vcf.gz \
      -O ${meta.id}.filtered.vcf.gz

    [[ -f ${meta.id}.filtered.vcf.gz.tbi ]] || \
      gatk IndexFeatureFile -I ${meta.id}.filtered.vcf.gz
    """

    stub:
    """
    touch ${meta.id}.filtered.vcf.gz ${meta.id}.filtered.vcf.gz.tbi
    """
}
