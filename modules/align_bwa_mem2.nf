process ALIGN_BWA_MEM2 {
    tag "${meta.id}"
    label 'align'
    input:
    tuple val(meta), path(r1), path(r2)
    path ref_files
    val ref_name
    output:
    tuple val(meta), path("${meta.id}.aligned.sam.gz"), emit: sam
    script:
    def rg = "@RG\\tID:${meta.id}\\tSM:${meta.id}\\tLB:${meta.library}\\tPL:${meta.platform}"
    """
    set -euo pipefail
    bwa-mem2 mem -t ${task.cpus} -R '${rg}' ${ref_name} ${r1} ${r2} | gzip -1 > ${meta.id}.aligned.sam.gz
    """
    stub:
    """
    printf '@HD\\tVN:1.6\\tSO:unsorted\\n@SQ\\tSN:chrSynthetic\\tLN:12000\\n' | gzip -c > ${meta.id}.aligned.sam.gz
    """
}
