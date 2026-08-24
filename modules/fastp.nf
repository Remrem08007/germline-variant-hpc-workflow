process FASTP {
    tag "${meta.id}"
    label 'small'
    publishDir { "${params.outdir}/qc/fastp/${meta.id}" }, mode: 'copy', overwrite: true
    input:
    tuple val(meta), path(r1), path(r2)
    output:
    tuple val(meta), path("${meta.id}.trimmed_R1.fastq.gz"), path("${meta.id}.trimmed_R2.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.fastp.json"), path("${meta.id}.fastp.html"), emit: reports
    script:
    """
    fastp \\
      --thread ${task.cpus} \\
      --in1 ${r1} --in2 ${r2} \\
      --out1 ${meta.id}.trimmed_R1.fastq.gz \\
      --out2 ${meta.id}.trimmed_R2.fastq.gz \\
      --qualified_quality_phred ${params.fastp_qualified_quality_phred} \\
      --length_required ${params.fastp_min_length} \\
      --json ${meta.id}.fastp.json \\
      --html ${meta.id}.fastp.html
    """
    stub:
    """
    touch ${meta.id}.trimmed_R1.fastq.gz ${meta.id}.trimmed_R2.fastq.gz
    echo '{}' > ${meta.id}.fastp.json
    touch ${meta.id}.fastp.html
    """
}
