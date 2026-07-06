#!/usr/bin/env bash
set -euo pipefail

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SLURM_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
source "${SLURM_DIR}/config.sh"

mkdir -p "${LOG_DIR}/slurm"

timestamp="$(date +%Y%m%d_%H%M%S)"
runner_log="${LOG_DIR}/slurm/run_pipeline_slurm_${timestamp}.log"
exec > >(tee -a "${runner_log}") 2>&1

elapsed_time() {
    local start="$1"
    local end="$2"
    local elapsed=$((end - start))
    printf "%02d:%02d:%02d" $((elapsed / 3600)) $(((elapsed % 3600) / 60)) $((elapsed % 60))
}

require_program() {
    local program="$1"
    if ! command -v "${program}" >/dev/null 2>&1; then
        echo "ERROR: required command not found: ${program}" >&2
        exit 1
    fi
}

count_lines() {
    local file="$1"
    if [[ ! -s "${file}" ]]; then
        echo 0
    else
        wc -l < "${file}" | tr -d ' '
    fi
}

run_bash_step() {
    local label="$1"
    local script="$2"
    local start
    local end

    echo
    echo "============================================================"
    echo "${label}"
    echo "Started: $(date)"
    echo "Script: ${script}"
    echo "============================================================"

    start="$(date +%s)"
    bash "${script}"
    end="$(date +%s)"

    echo "${label} finished: $(date)"
    echo "${label} elapsed: $(elapsed_time "${start}" "${end}")"
}

run_slurm_step() {
    local label="$1"
    local script="$2"
    local start
    local end

    echo
    echo "============================================================"
    echo "${label}"
    echo "Started: $(date)"
    echo "Submitting with sbatch --wait: ${script}"
    echo "============================================================"

    start="$(date +%s)"
    sbatch --wait "${script}"
    end="$(date +%s)"

    echo "${label} finished: $(date)"
    echo "${label} elapsed: $(elapsed_time "${start}" "${end}")"
}

print_summary() {
    local final_fa="${FINAL_OUTDIR}/final_potential_new_TEs.fa"

    echo
    echo "============================================================"
    echo "Final summary"
    echo "============================================================"
    echo "Genome table: ${GENOME_TABLE}"
    echo "Genomes: $(count_lines "${GENOME_TABLE}")"
    echo "MCHelper table: ${MCHELPER_TABLE}"
    echo "MCHelper inputs: $(count_lines "${MCHELPER_TABLE}")"
    echo "Final output directory: ${FINAL_OUTDIR}"
    echo "Final FASTA: ${final_fa}"
    if [[ -e "${final_fa}" ]]; then
        echo "Final candidate TE families: $(grep -c '^>' "${final_fa}" || true)"
    else
        echo "Final candidate TE families: 0"
    fi
    echo "Runner log: ${runner_log}"
    echo "SLURM logs: ${LOG_DIR}/slurm"
    echo "Finished: $(date)"
    echo "============================================================"
}

require_program sbatch

pipeline_start="$(date +%s)"

echo "============================================================"
echo "TE candidate discovery pipeline"
echo "Execution mode: SLURM sequential runner"
echo "Started: $(date)"
echo "Project directory: ${PROJECT_DIR}"
echo "SLURM config: ${SLURM_DIR}/config.sh"
echo "Runner log: ${runner_log}"
echo "============================================================"

run_bash_step "Dependency check" "${SLURM_DIR}/check_dependencies.sh"

run_bash_step "Step 0: prepare genome table" "${SLURM_DIR}/00_prepare_genome_table.sh"

n_genomes="$(count_lines "${GENOME_TABLE}")"
if [[ "${n_genomes}" -lt 1 ]]; then
    echo "ERROR: no genomes found in ${GENOME_TABLE}" >&2
    exit 1
fi

run_slurm_step "Step 1: RepeatModeler" "${SLURM_DIR}/Step1_run_repeatmodeler.slurm.sh"
run_slurm_step "Step 2: remove known TE families" "${SLURM_DIR}/Step2_run_TE_candidates_original_headers.slurm.sh"

run_bash_step "Step 3 preparation: prepare MCHelper table" "${SLURM_DIR}/02_prepare_mchelper_table.sh"

n_mchelper="$(count_lines "${MCHELPER_TABLE}")"
if [[ "${n_mchelper}" -lt 1 ]]; then
    echo "ERROR: no MCHelper inputs found in ${MCHELPER_TABLE}" >&2
    exit 1
fi

run_slurm_step "Step 3: MCHelper" "${SLURM_DIR}/Step3_run_mchelper.slurm.sh"
run_slurm_step "Step 4: final BLAST filtering" "${SLURM_DIR}/Step4_run_final_TE_filter_after_MCHelper.slurm.sh"

pipeline_end="$(date +%s)"
print_summary
echo "Total elapsed: $(elapsed_time "${pipeline_start}" "${pipeline_end}")"
