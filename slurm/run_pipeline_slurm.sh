#!/usr/bin/env bash
set -euo pipefail

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SLURM_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

if [[ ! -s "${PROJECT_DIR}/config.sh" ]]; then
    echo "ERROR: config.sh not found in ${PROJECT_DIR}" >&2
    exit 1
fi

source "${PROJECT_DIR}/config.sh"

mkdir -p "${LOG_DIR}" "${LOG_DIR}/slurm"

timestamp="$(date +%Y%m%d_%H%M%S)"
launcher_log="${LOG_DIR}/slurm/run_pipeline_slurm_${timestamp}.log"
exec > >(tee -a "${launcher_log}") 2>&1

elapsed_time() {
    local start="$1"
    local end="$2"
    local elapsed=$((end - start))
    printf "%02d:%02d:%02d" $((elapsed / 3600)) $(((elapsed % 3600) / 60)) $((elapsed % 60))
}

require_program() {
    local program="$1"
    if ! command -v "${program}" >/dev/null 2>&1; then
        echo "ERROR: required SLURM command not found: ${program}" >&2
        exit 1
    fi
}

submit_job() {
    local job_name="$1"
    local script_path="$2"
    local cpus="$3"
    local mem="$4"
    local time_limit="$5"
    local dependency="${6:-}"
    shift 6 || true
    local extra_args=("$@")

    local sbatch_args=(
        --parsable
        --job-name "${job_name}"
        --output "${LOG_DIR}/slurm/%x_%A_%a.out"
        --error "${LOG_DIR}/slurm/%x_%A_%a.err"
        --chdir "${PROJECT_DIR}"
    )

    if [[ -n "${SLURM_PARTITION}" ]]; then
        sbatch_args+=(--partition "${SLURM_PARTITION}")
    fi
    if [[ -n "${cpus}" ]]; then
        sbatch_args+=(--cpus-per-task "${cpus}")
    fi
    if [[ -n "${mem}" ]]; then
        sbatch_args+=(--mem "${mem}")
    fi
    if [[ -n "${time_limit}" ]]; then
        sbatch_args+=(--time "${time_limit}")
    fi

    if [[ -n "${dependency}" ]]; then
        sbatch_args+=(--dependency "${dependency}")
    fi

    sbatch_args+=("${extra_args[@]}" "${script_path}")
    sbatch "${sbatch_args[@]}"
}

submit_wait_wrap() {
    local job_name="$1"
    local dependency="$2"
    local command="$3"

    local sbatch_args=(
        --wait
        --job-name "${job_name}"
        --output "${LOG_DIR}/slurm/%x_%j.out"
        --error "${LOG_DIR}/slurm/%x_%j.err"
        --chdir "${PROJECT_DIR}"
        --wrap "${command}"
    )

    if [[ -n "${SLURM_PARTITION}" ]]; then
        sbatch_args+=(--partition "${SLURM_PARTITION}")
    fi

    if [[ -n "${dependency}" ]]; then
        sbatch_args+=(--dependency "${dependency}")
    fi

    sbatch "${sbatch_args[@]}"
}

count_lines() {
    local file="$1"
    if [[ ! -s "${file}" ]]; then
        echo 0
    else
        wc -l < "${file}" | tr -d ' '
    fi
}

array_spec() {
    local n_tasks="$1"
    local spec="1-${n_tasks}"
    if [[ -n "${ARRAY_CONCURRENCY}" ]]; then
        spec="${spec}%${ARRAY_CONCURRENCY}"
    fi
    echo "${spec}"
}

print_configuration_summary() {
    local n_genomes="$1"

    echo "============================================================"
    echo "TE candidate discovery pipeline"
    echo "Version: ${VERSION:-unknown}"
    echo "Execution mode: SLURM"
    echo "Started: $(date)"
    echo "Project directory: ${PROJECT_DIR}"
    echo "Genome directory: ${GENOME_DIR}"
    echo "Curated TE library: ${CURATED_TE_LIBRARY}"
    echo "Number of genomes: ${n_genomes}"
    echo
    echo "RepeatModeler settings:"
    echo "  Threads: ${REPEATMODELER_THREADS}"
    echo "  Thread option: ${REPEATMODELER_THREADS_OPTION}"
    echo "  LTRStruct: ${REPEATMODELER_USE_LTRSTRUCT}"
    echo
    echo "Step 2 filtering thresholds:"
    echo "  Identity: ${KNOWN_TE_MIN_IDENTITY}"
    echo "  Query coverage: ${KNOWN_TE_MIN_QCOV}"
    echo "  Minimum length: ${KNOWN_TE_MIN_LENGTH}"
    echo
    echo "MCHelper settings:"
    echo "  Threads: ${MCHELPER_THREADS}"
    echo "  -x: ${MCHELPER_X}"
    echo "  -e: ${MCHELPER_EXTENSION}"
    echo
    echo "CD-HIT settings:"
    echo "  Identity: ${CDHIT_IDENTITY}"
    echo "  Shorter coverage: ${CDHIT_SHORTER_COVERAGE}"
    echo "  Longer coverage: ${CDHIT_LONGER_COVERAGE}"
    echo
    echo "Final BLAST e-value: ${FINAL_BLAST_EVALUE}"
    echo "Launcher log: ${launcher_log}"
    echo "SLURM logs: ${LOG_DIR}/slurm"
    echo "============================================================"
    echo
}

print_final_summary() {
    echo
    echo "============================================================"
    echo "Final summary"
    echo "============================================================"
    echo "Genomes in ${GENOME_TABLE}: $(count_lines "${GENOME_TABLE}")"

    if [[ -s "${CANDIDATE_OUTDIR}/summary.tsv" ]]; then
        echo "Candidate libraries in Step 2 summary: $(( $(count_lines "${CANDIDATE_OUTDIR}/summary.tsv") - 1 ))"
    else
        echo "Candidate libraries in Step 2 summary: 0"
    fi

    local mchelper_count=0
    for fa in "${MCHELPER_OUTDIR}"/MCHelper_output_*/curated_sequences_NR.fa; do
        [[ -s "${fa}" ]] || continue
        mchelper_count=$((mchelper_count + $(grep -c '^>' "${fa}" || true)))
    done
    echo "MCHelper curated sequences: ${mchelper_count}"

    local final_fa="${FINAL_OUTDIR}/final_potential_new_TEs.fa"
    if [[ -e "${final_fa}" ]]; then
        echo "Final candidate TE families: $(grep -c '^>' "${final_fa}" || true)"
    else
        echo "Final candidate TE families: 0"
    fi

    echo "Final output directory: ${FINAL_OUTDIR}"
    echo "Final FASTA: ${final_fa}"
    echo "Finished: $(date)"
    echo "============================================================"
}

require_program sbatch

pipeline_start="$(date +%s)"

echo "Checking software dependencies before SLURM submission..."
bash "${PROJECT_DIR}/check_dependencies.sh"
echo

echo "Step 0: preparing genome table"
step_start="$(date +%s)"
bash "${PROJECT_DIR}/00_prepare_genome_table.sh"
step_end="$(date +%s)"
echo "Step 0 finished: $(date)"
echo "Step 0 elapsed: $(elapsed_time "${step_start}" "${step_end}")"
echo

n_genomes="$(count_lines "${GENOME_TABLE}")"
if [[ "${n_genomes}" -lt 1 ]]; then
    echo "ERROR: no genomes found in ${GENOME_TABLE}" >&2
    exit 1
fi

print_configuration_summary "${n_genomes}"

step1_array="$(array_spec "${n_genomes}")"
echo "Submitting Step 1 RepeatModeler array: ${step1_array}"
step1_job="$(submit_job \
    TE_step1_repeatmodeler \
    "${SLURM_DIR}/Step1_run_repeatmodeler_array.slurm" \
    "${STEP1_CPUS}" "${STEP1_MEM}" "${STEP1_TIME}" "" \
    --array "${step1_array}")"
step1_job="${step1_job%%;*}"
echo "Step 1 job ID: ${step1_job}"

echo "Submitting Step 2 after Step 1"
step2_job="$(submit_job \
    TE_step2_candidates \
    "${SLURM_DIR}/Step2_run_TE_candidates_original_headers.slurm" \
    "${STEP2_CPUS}" "${STEP2_MEM}" "${STEP2_TIME}" \
    "afterok:${step1_job}")"
step2_job="${step2_job%%;*}"
echo "Step 2 job ID: ${step2_job}"

echo "Waiting for Step 2 before preparing MCHelper table..."
submit_wait_wrap \
    TE_prepare_mchelper \
    "afterok:${step2_job}" \
    "cd '${PROJECT_DIR}' && bash '${PROJECT_DIR}/02_prepare_mchelper_table.sh'"

n_mchelper="$(count_lines "${MCHELPER_TABLE}")"
if [[ "${n_mchelper}" -lt 1 ]]; then
    echo "ERROR: no MCHelper inputs found in ${MCHELPER_TABLE}" >&2
    exit 1
fi

step3_array="$(array_spec "${n_mchelper}")"
echo "Submitting Step 3 MCHelper array: ${step3_array}"
step3_job="$(submit_job \
    TE_step3_mchelper \
    "${SLURM_DIR}/Step3_run_mchelper_array.slurm" \
    "${STEP3_CPUS}" "${STEP3_MEM}" "${STEP3_TIME}" "" \
    --array "${step3_array}")"
step3_job="${step3_job%%;*}"
echo "Step 3 job ID: ${step3_job}"

echo "Submitting Step 4 after Step 3"
step4_job="$(submit_job \
    TE_step4_final_filter \
    "${SLURM_DIR}/Step4_run_final_TE_filter_after_MCHelper.slurm" \
    "${STEP4_CPUS}" "${STEP4_MEM}" "${STEP4_TIME}" \
    "afterok:${step3_job}")"
step4_job="${step4_job%%;*}"
echo "Step 4 job ID: ${step4_job}"

echo "Waiting for Step 4 before printing final summary..."
submit_wait_wrap \
    TE_final_summary_barrier \
    "afterok:${step4_job}" \
    "cd '${PROJECT_DIR}' && true"

pipeline_end="$(date +%s)"
print_final_summary
echo "Total elapsed: $(elapsed_time "${pipeline_start}" "${pipeline_end}")"
