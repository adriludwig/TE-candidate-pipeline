#!/usr/bin/env bash
#SBATCH --job-name=TE_step3_mchelper
#SBATCH --cpus-per-task=64
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/slurm/%x_%j.out
#SBATCH --error=logs/slurm/%x_%j.err
#SBATCH --partition=low

# Do not use "set -e" here. Some genomes may produce no MCHelper output, and
# the script should record those cases and continue with the next genome.
set -uo pipefail

step_start="$(date +%s)"

# Submit this script from the pipeline run directory:
#   sbatch slurm/Step3_run_mchelper.slurm.sh
PROJECT_DIR="${PROJECT_DIR:-${SLURM_SUBMIT_DIR:-$(pwd -P)}}"

cd "${PROJECT_DIR}"
SLURM_DIR="${PROJECT_DIR}/slurm"
source "${SLURM_DIR}/config.sh"

mkdir -p "${LOG_DIR}/slurm" "${MCHELPER_OUTDIR}"

echo "============================================================"
echo "Step 3: MCHelper"
echo "Started: $(date)"
echo "SLURM job ID: ${SLURM_JOB_ID:-NA}"
echo "Project directory: ${PROJECT_DIR}"
echo "MCHelper table: ${MCHELPER_TABLE}"
echo "============================================================"

if [[ ! -s "${MCHELPER_TABLE}" ]]; then
    echo "ERROR: MCHelper table not found: ${MCHELPER_TABLE}" >&2
    echo "Run this first after Step 2 finishes: bash slurm/02_prepare_mchelper_table.sh" >&2
    exit 1
fi

if [[ ! -e "${BUSCO_LINEAGE}" ]]; then
    echo "ERROR: BUSCO lineage path not found: ${BUSCO_LINEAGE}" >&2
    exit 1
fi

if [[ ! -s "${MCHELPER_PY}" ]]; then
    echo "ERROR: MCHelper.py not found: ${MCHELPER_PY}" >&2
    exit 1
fi

load_mchelper_environment

status_file="${MCHELPER_OUTDIR}/mchelper_step3_status.tsv"
printf "genome_id\tstatus\toutput\n" > "${status_file}"

while IFS=$'\t' read -r genome_id input_fa genome_fa; do
    [[ -n "${genome_id}" ]] || continue

    outdir="${MCHELPER_OUTDIR}/MCHelper_output_${genome_id}"
    final_curated="${outdir}/curated_sequences_NR.fa"

    if [[ -s "${final_curated}" ]]; then
        echo "Skipping ${genome_id}: ${final_curated} already exists."
        printf "%s\tskipped_existing\t%s\n" "${genome_id}" "${final_curated}" >> "${status_file}"
        echo
        continue
    fi

    if [[ ! -s "${input_fa}" ]]; then
        echo "WARNING: candidate FASTA not found or empty for ${genome_id}: ${input_fa}" >&2
        printf "%s\tmissing_candidate_fasta\t%s\n" "${genome_id}" "${input_fa}" >> "${status_file}"
        continue
    fi

    if [[ ! -s "${genome_fa}" ]]; then
        echo "WARNING: genome FASTA not found or empty for ${genome_id}: ${genome_fa}" >&2
        printf "%s\tmissing_genome_fasta\t%s\n" "${genome_id}" "${genome_fa}" >> "${status_file}"
        continue
    fi

    mkdir -p "${outdir}"

    echo "------------------------------------------------------------"
    echo "Genome ID: ${genome_id}"
    echo "Candidate FASTA: ${input_fa}"
    echo "Genome FASTA: ${genome_fa}"
    echo "Output directory: ${outdir}"
    echo "MCHelper -x: ${MCHELPER_X}"
    echo "MCHelper -e: ${MCHELPER_EXTENSION}"
    echo "Threads: ${MCHELPER_THREADS}"

    python3 "${MCHELPER_PY}" \
        -r A \
        -l "${input_fa}" \
        --te_aid N \
        -v Y \
        -x "${MCHELPER_X}" \
        -e "${MCHELPER_EXTENSION}" \
        -t "${MCHELPER_THREADS}" \
        -o "${outdir}" \
        -g "${genome_fa}" \
        --input_type fasta \
        -a F \
        -n "${genome_id}" \
        -b "${BUSCO_LINEAGE}"

    mchelper_exit=$?

    if [[ "${mchelper_exit}" -ne 0 ]]; then
        echo "WARNING: MCHelper failed for ${genome_id} with exit code ${mchelper_exit}; continuing." >&2
        printf "%s\tfailed_exit_%s\t%s\n" "${genome_id}" "${mchelper_exit}" "${outdir}" >> "${status_file}"
        echo
        continue
    fi

    if [[ ! -s "${final_curated}" ]]; then
        echo "WARNING: MCHelper finished but did not create expected file for ${genome_id}: ${final_curated}" >&2
        printf "%s\tno_curated_output\t%s\n" "${genome_id}" "${final_curated}" >> "${status_file}"
        echo
        continue
    fi

    n_curated="$(grep -c '^>' "${final_curated}" || true)"
    echo "Curated MCHelper sequences: ${n_curated}"
    printf "%s\tdone_%s_sequences\t%s\n" "${genome_id}" "${n_curated}" "${final_curated}" >> "${status_file}"
    echo

done < "${MCHELPER_TABLE}"

step_end="$(date +%s)"
echo "Step 3 finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
echo "Status table: ${status_file}"