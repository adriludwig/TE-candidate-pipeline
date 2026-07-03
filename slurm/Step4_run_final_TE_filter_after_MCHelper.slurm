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

mkdir -p "${LOG_DIR}" "${FINAL_OUTDIR}"

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
    bash "${PROJECT_DIR}/Step4_run_final_TE_filter_after_MCHelper.sh"
fi

step_end="$(date +%s)"
echo "Finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
