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

echo "============================================================"
echo "Step 1: RepeatModeler"
echo "Started: $(date)"
echo "SLURM job ID: ${SLURM_JOB_ID:-NA}"
echo "SLURM array task ID: ${SLURM_ARRAY_TASK_ID:-NA}"
echo "Project directory: ${PROJECT_DIR}"
echo "============================================================"

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID is not set." >&2
    exit 1
fi

if [[ ! -s "${GENOME_TABLE}" ]]; then
    echo "ERROR: genome table not found: ${GENOME_TABLE}" >&2
    exit 1
fi

line="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${GENOME_TABLE}")"
if [[ -z "${line}" ]]; then
    echo "ERROR: no genome table row for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}" >&2
    exit 1
fi

IFS=$'\t' read -r genome_id genome_fa <<< "${line}"

if [[ -z "${genome_id}" || -z "${genome_fa}" ]]; then
    echo "ERROR: malformed genome table row: ${line}" >&2
    exit 1
fi

if [[ ! -s "${genome_fa}" ]]; then
    echo "ERROR: genome FASTA not found or empty: ${genome_fa}" >&2
    exit 1
fi

if [[ "${REPEATMODELER_MODE}" != "environment" ]]; then
    echo "ERROR: this SLURM script expects REPEATMODELER_MODE=\"environment\"." >&2
    exit 1
fi

if [[ "${REPEATMODELER_THREADS_OPTION}" != "-pa" && "${REPEATMODELER_THREADS_OPTION}" != "-threads" ]]; then
    echo "ERROR: REPEATMODELER_THREADS_OPTION must be either -pa or -threads" >&2
    exit 1
fi

outdir="${REPEATMODELER_OUTDIR}/${genome_id}"
workdir="${outdir}/repeatmodeler_work"
db="${genome_id}_db"

mkdir -p "${LOG_DIR}" "${REPEATMODELER_OUTDIR}" "${outdir}" "${workdir}"

if [[ -s "${outdir}/consensi.fa.classified" ]]; then
    echo "Step 1 output already exists for ${genome_id}; skipping."
    echo "Existing output: ${outdir}/consensi.fa.classified"
    step_end="$(date +%s)"
    echo "Finished: $(date)"
    echo "Elapsed seconds: $((step_end - step_start))"
    exit 0
fi

load_repeatmodeler_environment

echo "RepeatModeler executable: $(command -v RepeatModeler)"
echo "BuildDatabase executable: $(command -v BuildDatabase)"
echo "Genome ID: ${genome_id}"
echo "Genome FASTA: ${genome_fa}"
echo "Output directory: ${outdir}"
echo "Work directory: ${workdir}"
echo "Database name: ${db}"
echo "Threads: ${REPEATMODELER_THREADS}"
echo "Thread option: ${REPEATMODELER_THREADS_OPTION}"
echo "Use LTRStruct: ${REPEATMODELER_USE_LTRSTRUCT}"

cd "${workdir}"

echo "Running BuildDatabase..."
BuildDatabase -name "${db}" "${genome_fa}"

repeatmodeler_cmd=(
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

step_end="$(date +%s)"
echo "Finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
