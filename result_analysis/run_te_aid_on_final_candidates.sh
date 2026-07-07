#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# User settings
###############################################################################

# Final candidate TE FASTA produced by the pipeline.
INPUT_FASTA="final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa"

# Directory containing the genome FASTA files used in the pipeline.
# TE-Aid needs the genome where each candidate was recovered.
GENOME_DIR="."

# Genome FASTA suffix.
# Example: if genomes are GCA_000001.fna, use ".fna"
# Example: if genomes are GCA_000001_renamed_only_chrom.fna, use "_renamed_only_chrom.fna"
GENOME_SUFFIX=".fna"

# Path to the TE-Aid executable.
TEAID="/path/to/TE-Aid/TE-Aid"

# Output directory.
OUTDIR="te_aid_final_candidates"

load_teaid_environment() {
    # Edit this function if TE-Aid needs a conda/micromamba environment.
    #
    # Conda example:
    # source "$(conda info --base)/etc/profile.d/conda.sh"
    # conda activate teaid
    #
    # Micromamba example:
    # eval "$(/path/to/micromamba shell hook --shell bash)"
    # micromamba activate teaid
    :
}

###############################################################################
# Script
###############################################################################

if [[ ! -s "${INPUT_FASTA}" ]]; then
    echo "ERROR: input FASTA not found or empty: ${INPUT_FASTA}" >&2
    exit 1
fi

if [[ ! -d "${GENOME_DIR}" ]]; then
    echo "ERROR: genome directory not found: ${GENOME_DIR}" >&2
    exit 1
fi

if [[ ! -x "${TEAID}" ]]; then
    echo "ERROR: TE-Aid executable not found or not executable: ${TEAID}" >&2
    exit 1
fi

mkdir -p "${OUTDIR}/single_fastas"

load_teaid_environment

PROJECT_DIR="$(pwd -P)"

echo "Input FASTA: ${INPUT_FASTA}"
echo "Genome directory: ${GENOME_DIR}"
echo "Genome suffix: ${GENOME_SUFFIX}"
echo "TE-Aid executable: ${TEAID}"
echo "Output directory: ${OUTDIR}"
echo

echo "=== Splitting final candidate FASTA ==="

awk -v outdir="${OUTDIR}/single_fastas" '
    /^>/ {
        if (out) close(out)

        header = substr($0, 2)
        filename = header

        gsub(/#/, "_", filename)
        gsub(/\//, "_", filename)
        gsub(/\|/, "_", filename)
        gsub(/[^A-Za-z0-9_.-]/, "_", filename)

        out = outdir "/" filename ".fa"
        print ">" header > out
        next
    }

    {
        print $0 >> out
    }
' "${INPUT_FASTA}"

echo "=== Running TE-Aid ==="

summary="${OUTDIR}/te_aid_run_summary.tsv"
printf "candidate_fasta\tgenome_id\tgenome_fasta\tstatus\n" > "${summary}"

for file in "${OUTDIR}/single_fastas"/*.fa; do
    [[ -s "${file}" ]] || continue

    base="$(basename "${file}" .fa)"

    # The pipeline prefixes final headers with genome_id|candidate_id.
    # After filename sanitization, this usually becomes genome_id_candidate_id.
    genome_id="${base%%_*}"

    # More specific extraction for NCBI GCA/GCF-style accessions.
    accession="$(printf "%s\n" "${base}" | grep -oE '^(GCA|GCF)_[0-9]+(\.[0-9]+)?' || true)"
    if [[ -n "${accession}" ]]; then
        genome_id="${accession}"
    fi

    genome="${GENOME_DIR}/${genome_id}${GENOME_SUFFIX}"

    if [[ ! -s "${genome}" ]]; then
        echo "WARNING: genome not found for ${file}: ${genome}" >&2
        printf "%s\t%s\t%s\tmissing_genome\n" "${file}" "${genome_id}" "${genome}" >> "${summary}"
        continue
    fi

    echo "Running TE-Aid:"
    echo "  TE:     ${file}"
    echo "  genome: ${genome}"

    if [[ "${file}" = /* ]]; then
        candidate_abs="${file}"
    else
        candidate_abs="${PROJECT_DIR}/${file}"
    fi

    if [[ "${genome}" = /* ]]; then
        genome_abs="${genome}"
    else
        genome_abs="${PROJECT_DIR}/${genome}"
    fi

    (
        cd "${OUTDIR}"
        "${TEAID}" -q "${candidate_abs}" -g "${genome_abs}"
    )

    printf "%s\t%s\t%s\tdone\n" "${file}" "${genome_id}" "${genome}" >> "${summary}"
done

echo
echo "=== Done ==="
echo "Summary: ${summary}"
