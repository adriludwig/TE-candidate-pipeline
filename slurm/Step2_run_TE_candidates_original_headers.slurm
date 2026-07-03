#!/usr/bin/env bash
set -euo pipefail

step_start="$(date +%s)"

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SLURM_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
source "${PROJECT_DIR}/config.sh"

mkdir -p "${LOG_DIR}" "${CANDIDATE_OUTDIR}"

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
    bash "${PROJECT_DIR}/Step2_run_TE_candidates_original_headers.sh"
fi

step_end="$(date +%s)"
echo "Finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
