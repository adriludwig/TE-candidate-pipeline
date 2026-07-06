#!/usr/bin/env bash
#SBATCH --job-name=TE_step2_candidates
#SBATCH --cpus-per-task=16
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/slurm/%x_%j.out
#SBATCH --error=logs/slurm/%x_%j.err
#SBATCH --partition=low

set -euo pipefail

step_start="$(date +%s)"

# Submit this script from the pipeline run directory:
#   sbatch slurm/Step2_run_TE_candidates_original_headers.slurm
PROJECT_DIR="${PROJECT_DIR:-${SLURM_SUBMIT_DIR:-$(pwd -P)}}"

cd "${PROJECT_DIR}"
SLURM_DIR="${PROJECT_DIR}/slurm"
source "${SLURM_DIR}/config.sh"

mkdir -p "${LOG_DIR}/slurm" "${CANDIDATE_OUTDIR}"

echo "============================================================"
echo "Step 2: remove known TE families"
echo "Started: $(date)"
echo "SLURM job ID: ${SLURM_JOB_ID:-NA}"
echo "Project directory: ${PROJECT_DIR}"
echo "============================================================"

summary="${CANDIDATE_OUTDIR}/summary.tsv"
if [[ -s "${summary}" ]]; then
    echo "Step 2 output already exists; skipping."
    echo "Existing summary: ${summary}"
else
    load_filtering_environment

    "${SLURM_DIR}/TE_candidate_pipeline_original_headers.sh" \
        --input_dir "${REPEATMODELER_OUTDIR}" \
        --library "${CURATED_TE_LIBRARY}" \
        --output_dir "${CANDIDATE_OUTDIR}" \
        --consensi_name "consensi.fa.classified" \
        --identity "${KNOWN_TE_MIN_IDENTITY}" \
        --coverage "${KNOWN_TE_MIN_QCOV}" \
        --min_length "${KNOWN_TE_MIN_LENGTH}" \
        --threads "${FILTER_THREADS}"
fi

step_end="$(date +%s)"
echo "Step 2 finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
