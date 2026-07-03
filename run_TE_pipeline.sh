#!/usr/bin/env bash
set -euo pipefail

# Run this script from the directory that contains:
#   - config.sh
#   - all Step*.sh scripts
#   - genome FASTA files, unless GENOME_DIR in config.sh points elsewhere
#   - curated TE library and db/ reference files, unless their paths were edited

RUN_DIR="$(pwd -P)"
SCRIPT_DIR="${RUN_DIR}"

if [[ ! -s "${SCRIPT_DIR}/config.sh" ]]; then
    echo "ERROR: config.sh not found in the current directory: ${SCRIPT_DIR}" >&2
    echo "Run this script from the folder that contains the pipeline scripts." >&2
    exit 1
fi

source "${SCRIPT_DIR}/config.sh"

mkdir -p "${LOG_DIR}"
log_file="${LOG_DIR}/TE_pipeline_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "${log_file}") 2>&1

echo "TE candidate discovery pipeline"
echo "Started: $(date)"
echo "Run directory: ${RUN_DIR}"
echo "Pipeline scripts directory: ${SCRIPT_DIR}"
echo "Log file: ${log_file}"
echo

echo "Step 0: preparing genome table"
bash "${SCRIPT_DIR}/00_prepare_genome_table.sh"

echo
echo "Step 1: running RepeatModeler"
bash "${SCRIPT_DIR}/Step1_run_repeatmodeler_loop.sh"

echo
echo "Step 2: removing known TE families"
bash "${SCRIPT_DIR}/Step2_run_TE_candidates_original_headers.sh"

echo
echo "Step 3 preparation: preparing MCHelper table"
bash "${SCRIPT_DIR}/02_prepare_mchelper_table.sh"

echo
echo "Step 3: running MCHelper"
bash "${SCRIPT_DIR}/Step3_run_mchelper_loop.sh"

echo
echo "Step 4: final filtering"
bash "${SCRIPT_DIR}/Step4_run_final_TE_filter_after_MCHelper.sh"

echo
echo "Pipeline finished: $(date)"
echo "Final output:"
echo "${FINAL_OUTDIR}/final_potential_new_TEs.fa"
