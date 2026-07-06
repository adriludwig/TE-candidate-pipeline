#!/usr/bin/env bash
#SBATCH --job-name=TE_step3_mchelper
#SBATCH --cpus-per-task=64
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/slurm/%x_%j.out
#SBATCH --error=logs/slurm/%x_%j.err
#SBATCH --partition=low

set -euo pipefail

step_start="$(date +%s)"

# Submit this script from the pipeline run directory:
#   sbatch slurm/Step3_run_mchelper.slurm
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
    echo "Run this first after Step 2 finishes: bash 02_prepare_mchelper_table.sh" >&2
    exit 1
fi

load_mchelper_environment

while IFS=$'\t' read -r genome_id input_fa genome_fa; do
    [[ -n "${genome_id}" ]] || continue

    if [[ ! -s "${input_fa}" ]]; then
        echo "ERROR: candidate FASTA not found or empty: ${input_fa}" >&2
        exit 1
    fi

    if [[ ! -s "${genome_fa}" ]]; then
        echo "ERROR: genome FASTA not found or empty: ${genome_fa}" >&2
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

    outdir="${MCHELPER_OUTDIR}/MCHelper_output_${genome_id}"
    final_curated="${outdir}/curated_sequences_NR.fa"

    if [[ -s "${final_curated}" ]]; then
        echo "Skipping ${genome_id}: ${final_curated} already exists."
        echo
        continue
    fi

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

    if [[ ! -s "${final_curated}" ]]; then
        echo "ERROR: MCHelper did not create expected file: ${final_curated}" >&2
        exit 1
    fi

    echo "Curated MCHelper sequences:"
    grep -c "^>" "${final_curated}" || true
    echo
done < "${MCHELPER_TABLE}"

step_end="$(date +%s)"
echo "Step 3 finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
