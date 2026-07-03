#!/usr/bin/env bash
set -euo pipefail

step_start="$(date +%s)"

# The launcher submits this job with --chdir set to the project directory.
# Do not derive paths from BASH_SOURCE here: SLURM copies submitted scripts to
# a spool directory before execution.
PROJECT_DIR="${PROJECT_DIR:-$(pwd -P)}"
SLURM_DIR="${PROJECT_DIR}/slurm"

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
