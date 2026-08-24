process FASTQC {
    tag "${meta.id}"
    label 'small'
    publishDir { "${params.outdir}/qc/fastqc/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(r1), path(r2)
    output:
    tuple val(meta), path("*_fastqc.html"), path("*_fastqc.zip"), emit: reports
    script:
    """
    fastqc --threads ${task.cpus} ${r1} ${r2}
    """
    stub:
    """
    touch ${r1.simpleName}_fastqc.html ${r1.simpleName}_fastqc.zip
    touch ${r2.simpleName}_fastqc.html ${r2.simpleName}_fastqc.zip
    """
}
