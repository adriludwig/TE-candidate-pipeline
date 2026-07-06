#!/usr/bin/env bash
#SBATCH --job-name=TE_step4_final_filter
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=logs/slurm/%x_%j.out
#SBATCH --error=logs/slurm/%x_%j.err
#SBATCH --partition=low

set -euo pipefail

step_start="$(date +%s)"

# Submit this script from the pipeline run directory:
#   sbatch slurm/Step4_run_final_TE_filter_after_MCHelper.slurm
PROJECT_DIR="${PROJECT_DIR:-${SLURM_SUBMIT_DIR:-$(pwd -P)}}"

cd "${PROJECT_DIR}"
SLURM_DIR="${PROJECT_DIR}/slurm"
source "${SLURM_DIR}/config.sh"

mkdir -p "${LOG_DIR}/slurm" "${FINAL_OUTDIR}"

echo "============================================================"
echo "Step 4: final BLAST filtering"
echo "Started: $(date)"
echo "SLURM job ID: ${SLURM_JOB_ID:-NA}"
echo "Project directory: ${PROJECT_DIR}"
echo "============================================================"

final_fa="${FINAL_OUTDIR}/final_potential_new_TEs.fa"
if [[ -e "${final_fa}" ]]; then
    echo "Step 4 output already exists; skipping."
    echo "Existing output: ${final_fa}"
else
    load_filtering_environment

    echo "Starting Step 4: $(date)"

    all_mchelper="${FINAL_OUTDIR}/all_MCHelper_curated_sequences_NR.with_genome.fa"
    : > "${all_mchelper}"

    total_genomes=0
    successful_genomes=0
    total_sequences=0

    for dir in "${MCHELPER_OUTDIR}"/MCHelper_output_*; do
        [[ -d "${dir}" ]] || continue
        total_genomes=$((total_genomes + 1))
        fa="${dir}/curated_sequences_NR.fa"
        [[ -s "${fa}" ]] || continue

        successful_genomes=$((successful_genomes + 1))
        genome_id="$(basename "${dir}")"
        genome_id="${genome_id#MCHelper_output_}"
        n="$(grep -c "^>" "${fa}" || true)"
        total_sequences=$((total_sequences + n))

        awk -v genome="${genome_id}" '
            /^>/ {
                sub(/^>/, ">" genome "|")
                print
                next
            }
            {print}
        ' "${fa}" >> "${all_mchelper}"
    done

    echo "Total MCHelper genome folders: ${total_genomes}"
    echo "Genomes with curated_sequences_NR.fa: ${successful_genomes}"
    echo "Sequences concatenated: ${total_sequences}"

    if [[ ! -s "${all_mchelper}" ]]; then
        echo "ERROR: no curated_sequences_NR.fa sequences were found." >&2
        exit 1
    fi

    cdhit_out="${FINAL_OUTDIR}/all_MCHelper_curated_sequences_NR.cdhit80.fa"
    cd-hit-est \
        -i "${all_mchelper}" \
        -o "${cdhit_out}" \
        -c "${CDHIT_IDENTITY}" \
        -aS "${CDHIT_SHORTER_COVERAGE}" \
        -aL "${CDHIT_LONGER_COVERAGE}" \
        -G 0 \
        -g 1 \
        -M 0 \
        -T "${FILTER_THREADS}"

    if [[ ! -s "${REPBASE_NT_FASTA}" ]]; then
        echo "ERROR: RepBase nucleotide FASTA not found: ${REPBASE_NT_FASTA}" >&2
        exit 1
    fi
    if [[ ! -s "${REPBASE_NT_DB_PREFIX}.nsq" && ! -s "${REPBASE_NT_DB_PREFIX}.00.nsq" ]]; then
        makeblastdb -in "${REPBASE_NT_FASTA}" -dbtype nucl -out "${REPBASE_NT_DB_PREFIX}"
    fi

    if [[ ! -s "${TE_PEP_FASTA}" ]]; then
        echo "ERROR: TE peptide FASTA not found: ${TE_PEP_FASTA}" >&2
        exit 1
    fi
    if [[ ! -s "${TE_PEP_DB_PREFIX}.psq" && ! -s "${TE_PEP_DB_PREFIX}.00.psq" ]]; then
        makeblastdb -in "${TE_PEP_FASTA}" -dbtype prot -out "${TE_PEP_DB_PREFIX}"
    fi

    repbase_blast="${FINAL_OUTDIR}/cdhit_candidates_vs_repbase_nt.blastn.tsv"
    blastn \
        -query "${cdhit_out}" \
        -db "${REPBASE_NT_DB_PREFIX}" \
        -out "${repbase_blast}" \
        -evalue "${FINAL_BLAST_EVALUE}" \
        -dust no \
        -soft_masking false \
        -num_threads "${FILTER_THREADS}" \
        -outfmt "6 qseqid sseqid pident length qlen slen qcovs evalue bitscore"

    awk -v max_e="${FINAL_BLAST_EVALUE}" \
        '($8 <= max_e) {print $1}' \
        "${repbase_blast}" | sort -u > "${FINAL_OUTDIR}/candidates_with_repbase_nt_hit.ids"

    pep_blast="${FINAL_OUTDIR}/cdhit_candidates_vs_TE_peptides.blastx.tsv"
    blastx \
        -query "${cdhit_out}" \
        -db "${TE_PEP_DB_PREFIX}" \
        -out "${pep_blast}" \
        -evalue "${FINAL_BLAST_EVALUE}" \
        -num_threads "${FILTER_THREADS}" \
        -outfmt "6 qseqid sseqid pident length qlen slen qcovs evalue bitscore"

    awk -v max_e="${FINAL_BLAST_EVALUE}" \
        '($8 <= max_e) {print $1}' \
        "${pep_blast}" | sort -u > "${FINAL_OUTDIR}/candidates_with_TE_peptide_hit.ids"

    cat \
        "${FINAL_OUTDIR}/candidates_with_repbase_nt_hit.ids" \
        "${FINAL_OUTDIR}/candidates_with_TE_peptide_hit.ids" | sort -u \
        > "${FINAL_OUTDIR}/candidates_to_keep.ids"

    if [[ -s "${FINAL_OUTDIR}/candidates_to_keep.ids" ]]; then
        seqkit grep -f "${FINAL_OUTDIR}/candidates_to_keep.ids" "${cdhit_out}" > "${final_fa}"
    else
        : > "${final_fa}"
    fi

    echo "Final retained potential TEs:"
    grep -c "^>" "${final_fa}" || true
    echo "Final FASTA: ${final_fa}"
fi

step_end="$(date +%s)"
echo "Step 4 finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
