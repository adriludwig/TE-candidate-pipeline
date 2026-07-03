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
echo "Step 3: MCHelper"
echo "Started: $(date)"
echo "SLURM job ID: ${SLURM_JOB_ID:-NA}"
echo "SLURM array task ID: ${SLURM_ARRAY_TASK_ID:-NA}"
echo "Project directory: ${PROJECT_DIR}"
echo "============================================================"

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID is not set." >&2
    exit 1
fi

if [[ ! -s "${MCHELPER_TABLE}" ]]; then
    echo "ERROR: MCHelper table not found: ${MCHELPER_TABLE}" >&2
    exit 1
fi

line="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${MCHELPER_TABLE}")"
if [[ -z "${line}" ]]; then
    echo "ERROR: no MCHelper table row for SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}" >&2
    exit 1
fi

IFS=$'\t' read -r genome_id input_fa genome_fa <<< "${line}"

if [[ -z "${genome_id}" || -z "${input_fa}" || -z "${genome_fa}" ]]; then
    echo "ERROR: malformed MCHelper table row: ${line}" >&2
    exit 1
fi

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

mkdir -p "${LOG_DIR}" "${MCHELPER_OUTDIR}"

if [[ -s "${final_curated}" ]]; then
    echo "Step 3 output already exists for ${genome_id}; skipping."
    echo "Existing output: ${final_curated}"
    step_end="$(date +%s)"
    echo "Finished: $(date)"
    echo "Elapsed seconds: $((step_end - step_start))"
    exit 0
fi

load_mchelper_environment

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

step_end="$(date +%s)"
echo "Finished: $(date)"
echo "Elapsed seconds: $((step_end - step_start))"
