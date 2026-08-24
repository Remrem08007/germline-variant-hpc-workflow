#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { FASTQC }           from './modules/fastqc'
include { FASTP }            from './modules/fastp'
include { ALIGN_BWA_MEM2 }   from './modules/align_bwa_mem2'
include { SORT_BAM }         from './modules/sort_bam'
include { MARK_DUPLICATES }  from './modules/mark_duplicates'
include { ALIGNMENT_QC }     from './modules/alignment_qc'
include { BQSR }             from './modules/bqsr'
include { HAPLOTYPE_CALLER } from './modules/haplotype_caller'
include { GENOTYPE_GVCF }    from './modules/genotype_gvcf'
include { HARD_FILTER }      from './modules/hard_filter'
include { VARIANT_STATS }    from './modules/variant_stats'


def requireParam(name, value) {
    if (value == null || value.toString().trim() == '') {
        error "Missing required parameter: --${name}"
    }
}


def resolveReadPath(sheetDir, String value, boolean checkExists) {
    def raw = java.nio.file.Paths.get(value)
    def resolved = raw.isAbsolute() ? raw : sheetDir.resolve(raw).normalize()
    return file(resolved.toString(), checkIfExists: checkExists)
}


def samplesheetChannel(String samplesheet, boolean stubMode) {
    def sheetPath = file(samplesheet, checkIfExists: true)
    def sheetDir = sheetPath.parent
    def seen = [] as Set

    return Channel
        .fromPath(sheetPath)
        .splitCsv(header: true)
        .map { row ->
            def sample = row.sample?.toString()?.trim()
            def read1 = row.fastq_1?.toString()?.trim()
            def read2 = row.fastq_2?.toString()?.trim()

            if (!sample || !read1 || !read2) {
                error "Samplesheet requires non-empty columns: sample,fastq_1,fastq_2"
            }
            if (!(sample ==~ /[A-Za-z0-9_.-]+/)) {
                error "Invalid sample identifier '${sample}'. Allowed: letters, numbers, '.', '_' and '-'."
            }
            if (!seen.add(sample)) {
                error "Duplicate sample identifier in samplesheet: '${sample}'"
            }

            def library = row.library?.toString()?.trim() ?: sample
            def platform = row.platform?.toString()?.trim() ?: 'ILLUMINA'

            tuple(
                [id: sample, library: library, platform: platform],
                resolveReadPath(sheetDir, read1, !stubMode),
                resolveReadPath(sheetDir, read2, !stubMode)
            )
        }
}


def referenceBundle(String reference, boolean stubMode) {
    def referencePath = file(reference, checkIfExists: true)
    def dictionary = reference.replaceFirst(/\.[^.]+$/, '') + '.dict'

    return [
        referencePath,
        file(reference + '.fai', checkIfExists: !stubMode),
        file(dictionary, checkIfExists: !stubMode),
        file(reference + '.0123', checkIfExists: !stubMode),
        file(reference + '.amb', checkIfExists: !stubMode),
        file(reference + '.ann', checkIfExists: !stubMode),
        file(reference + '.bwt.2bit.64', checkIfExists: !stubMode),
        file(reference + '.pac', checkIfExists: !stubMode)
    ]
}


def knownSitesBundle(String knownSites) {
    def files = []

    knownSites.split(',').each { raw ->
        def value = raw.trim()
        if (!value) {
            return
        }

        files << file(value, checkIfExists: true)

        def tabix = file(value + '.tbi')
        def tribble = file(value + '.idx')
        if (tabix.exists()) {
            files << tabix
        }
        else if (tribble.exists()) {
            files << tribble
        }
        else {
            error "Known-sites index not found for ${value}"
        }
    }

    if (!files) {
        error "No valid --known_sites VCFs were provided"
    }

    return files
}


workflow {
    requireParam('input', params.input)
    requireParam('reference', params.reference)
    if (!params.stub_mode) {
        requireParam('container_dir', params.container_dir)
    }

    samples_ch = samplesheetChannel(params.input, params.stub_mode as boolean)
    reference_files = referenceBundle(params.reference, params.stub_mode as boolean)
    reference_name = file(params.reference).name

    use_intervals = params.intervals ? true : false
    intervals = params.intervals \
        ? file(params.intervals, checkIfExists: true) \
        : file("${projectDir}/assets/empty.intervals", checkIfExists: true)

    FASTQC(samples_ch)
    FASTP(samples_ch)
    ALIGN_BWA_MEM2(FASTP.out.reads, reference_files, reference_name)
    SORT_BAM(ALIGN_BWA_MEM2.out.sam)
    MARK_DUPLICATES(SORT_BAM.out.bam)
    ALIGNMENT_QC(MARK_DUPLICATES.out.bam)

    if (params.skip_bqsr) {
        calling_bam = MARK_DUPLICATES.out.bam
    }
    else {
        requireParam('known_sites', params.known_sites)
        known_sites_files = knownSitesBundle(params.known_sites)
        BQSR(
            MARK_DUPLICATES.out.bam,
            reference_files,
            reference_name,
            known_sites_files,
            intervals,
            use_intervals
        )
        calling_bam = BQSR.out.bam
    }

    HAPLOTYPE_CALLER(
        calling_bam,
        reference_files,
        reference_name,
        intervals,
        use_intervals
    )
    GENOTYPE_GVCF(
        HAPLOTYPE_CALLER.out.gvcf,
        reference_files,
        reference_name,
        intervals,
        use_intervals
    )
    HARD_FILTER(GENOTYPE_GVCF.out.vcf, reference_files, reference_name)
    VARIANT_STATS(HARD_FILTER.out.vcf)
}
