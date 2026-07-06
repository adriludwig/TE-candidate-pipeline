#!/usr/bin/env bash
#SBATCH --job-name=TE_step1_repeatmodeler
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --output=logs/slurm/%x_%j.out
#SBATCH --error=logs/slurm/%x_%j.err

set -euo pipefail

step_start="$(date +%s)"

# Submit this script from the pipeline run directory:
#   sbatch slurm/Step1_run_repeatmodeler.slurm
PROJECT_DIR="${PROJECT_DIR:-${SLURM_SUBMIT_DIR:-$(pwd -P)}}"

cd "${PROJECT_DIR}"
SLURM_DIR="${PROJECT_DIR}/slurm"
source "${SLURM_DIR}/config.sh"

mkdir -p "${LOG_DIR}/slurm" "${REPEATMODELER_OUTDIR}"

echo "============================================================"
echo "Step 1: RepeatModeler"
echo "Started: $(date)"
echo "SLURM job ID: ${SLURM_JOB_ID:-NA}"
echo "Project directory: ${PROJECT_DIR}"
echo "Genome table: ${GENOME_TABLE}"
echo "============================================================"

if [[ ! -s "${GENOME_TABLE}" ]]; then
    echo "ERROR: genome table not found: ${GENOME_TABLE}" >&2
    echo "Run this first: bash 00_prepare_genome_table.sh" >&2
    exit 1
fi

if [[ "${REPEATMODELER_THREADS_OPTION}" != "-pa" && "${REPEATMODELER_THREADS_OPTION}" != "-threads" ]]; then
    echo "ERROR: REPEATMODELER_THREADS_OPTION must be either -pa or -threads" >&2
    exit 1
fi

module purge || true
module load singularity >/dev/null 2>&1 || module load apptainer >/dev/null 2>&1 || true

TETOOLS_SIF="${TETOOLS_SIF:-${SHARED:-/shared}/containers/dfam-tetools-latest.sif}"
TETOOLS_CONTAINER_CMD="${TETOOLS_CONTAINER_CMD:-singularity}"

if ! command -v "${TETOOLS_CONTAINER_CMD}" >/dev/null 2>&1; then
    if command -v singularity >/dev/null 2>&1; then
        TETOOLS_CONTAINER_CMD="singularity"
    elif command -v apptainer >/dev/null 2>&1; then
        TETOOLS_CONTAINER_CMD="apptainer"
    else
        echo "ERROR: neither singularity nor apptainer was found." >&2
        exit 1
    fi
fi

if [[ ! -s "${TETOOLS_SIF}" ]]; then
    echo "ERROR: TETools container image not found: ${TETOOLS_SIF}" >&2
    exit 1
fi

echo "Container command: ${TETOOLS_CONTAINER_CMD}"
echo "TETools image: ${TETOOLS_SIF}"
echo "Threads: ${REPEATMODELER_THREADS}"
echo "Thread option: ${REPEATMODELER_THREADS_OPTION}"
echo "Use LTRStruct: ${REPEATMODELER_USE_LTRSTRUCT}"
echo

while IFS=$'\t' read -r genome_id genome_fa; do
    [[ -n "${genome_id}" ]] || continue

    if [[ ! -s "${genome_fa}" ]]; then
        echo "ERROR: genome FASTA not found or empty: ${genome_fa}" >&2
        exit 1
    fi

    outdir="${REPEATMODELER_OUTDIR}/${genome_id}"
    workdir="/tmp/RM_${SLURM_JOB_ID:-manual}_${genome_id}"
    db="${genome_id}_db"

    mkdir -p "${outdir}" "${workdir}"

    if [[ -s "${outdir}/consensi.fa.classified" ]]; then
        echo "Skipping ${genome_id}: ${outdir}/consensi.fa.classified already exists."
        echo
        continue
    fi

    echo "------------------------------------------------------------"
    echo "Genome ID: ${genome_id}"
    echo "Genome FASTA: ${genome_fa}"
    echo "Output directory: ${outdir}"
    echo "Work directory: ${workdir}"
    echo "Database name: ${db}"

    cp "${genome_fa}" "${workdir}/"
    genome_copy="${workdir}/$(basename "${genome_fa}")"

    cd "${workdir}"

    echo "Running BuildDatabase..."
    "${TETOOLS_CONTAINER_CMD}" exec "${TETOOLS_SIF}" \
        BuildDatabase -name "${db}" "$(basename "${genome_copy}")"

    repeatmodeler_cmd=(
        "${TETOOLS_CONTAINER_CMD}"
        exec
        "${TETOOLS_SIF}"
        RepeatModeler
        -database "${db}"
        "${REPEATMODELER_THREADS_OPTION}" "${REPEATMODELER_THREADS}"
    )

    if [[ "${REPEATMODELER_USE_LTRSTRUCT}" == "yes" ]]; then
        repeatmodeler_cmd+=(-LTRStruct)
    elif [[ "${REPEATMODELER_USE_LTRSTRUCT}" != "no" ]]; then
        echo "ERROR: REPEATMODELER_USE_LTRSTRUCT must be yes or no" >&2
        exit 1
    fi

    echo "Running RepeatModeler..."
    echo "Command: ${repeatmodeler_cmd[*]}"
    "${repeatmodeler_cmd[@]}"

    if [[ ! -s "${db}-families.fa" ]]; then
        echo "ERROR: RepeatModeler did not create expected file: ${workdir}/${db}-families.fa" >&2
        exit 1
    fi

    cp "${db}-families.fa" "${outdir}/"
    cp "${db}-families.stk" "${outdir}/" 2>/dev/null || true
    cp RM_*/consensi.fa.classified "${outdir}/" 2>/dev/null || true
    cp RM_*/families-classified.stk "${outdir}/" 2>/dev/null || true
    cp RM_*/rmod.log "${outdir}/" 2>/dev/null || true

    if [[ ! -s "${outdir}/consensi.fa.classified" ]]; then
        echo "WARNING: consensi.fa.classified was not found for ${genome_id}" >&2
        echo "Step 2 expects this file. Check RepeatModeler output in: ${workdir}" >&2
    fi

    echo "Number of RepeatModeler families:"
    grep -c "^>" "${outdir}/${db}-families.fa" || true

    cd "${PROJECT_DIR}"
    rm -rf "${workdir}"
    echo
done < "${GENOME_TABLE}"

step_end="$(date +%s)"
echo "Step 1 finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
