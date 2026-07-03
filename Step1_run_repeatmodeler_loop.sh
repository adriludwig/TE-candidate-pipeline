#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${LOG_DIR}" "${REPEATMODELER_OUTDIR}"

if [[ ! -s "${GENOME_TABLE}" ]]; then
    echo "ERROR: genome table not found: ${GENOME_TABLE}" >&2
    echo "Run 00_prepare_genome_table.sh first." >&2
    exit 1
fi

if [[ "${REPEATMODELER_MODE}" != "environment" ]]; then
    echo "ERROR: this local script expects REPEATMODELER_MODE=\"environment\"." >&2
    echo "Edit config.sh and set: REPEATMODELER_MODE=\"environment\"" >&2
    exit 1
fi

if [[ "${REPEATMODELER_THREADS_OPTION}" != "-pa" && "${REPEATMODELER_THREADS_OPTION}" != "-threads" ]]; then
    echo "ERROR: REPEATMODELER_THREADS_OPTION must be either -pa or -threads" >&2
    exit 1
fi

load_repeatmodeler_environment

echo "RepeatModeler executable:"
which RepeatModeler
echo "BuildDatabase executable:"
which BuildDatabase
echo "RepeatModeler version/help:"
RepeatModeler 2>&1 | head -20 || true
echo

while IFS=$'\t' read -r genome_id genome_fa; do
    if [[ -z "${genome_id}" || -z "${genome_fa}" ]]; then
        echo "WARNING: skipping malformed line in ${GENOME_TABLE}" >&2
        continue
    fi

    if [[ ! -s "${genome_fa}" ]]; then
        echo "ERROR: genome FASTA not found or empty: ${genome_fa}" >&2
        exit 1
    fi

    outdir="${REPEATMODELER_OUTDIR}/${genome_id}"
    workdir="${outdir}/repeatmodeler_work"
    db="${genome_id}_db"

    mkdir -p "${outdir}" "${workdir}"

    echo "============================================================"
    echo "Running RepeatModeler for: ${genome_id}"
    echo "Genome FASTA: ${genome_fa}"
    echo "Output directory: ${outdir}"
    echo "Work directory: ${workdir}"
    echo "Database name: ${db}"
    echo "Threads: ${REPEATMODELER_THREADS}"
    echo "Thread option: ${REPEATMODELER_THREADS_OPTION}"
    echo "Use LTRStruct: ${REPEATMODELER_USE_LTRSTRUCT}"
    echo "Started: $(date)"
    echo "============================================================"

    cd "${workdir}"

    echo "Running BuildDatabase..."
    echo "Command: BuildDatabase -name ${db} ${genome_fa}"
    BuildDatabase -name "${db}" "${genome_fa}"

    echo "Files after BuildDatabase:"
    ls -lh

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

    echo "Copying RepeatModeler outputs to: ${outdir}"
    cp "${db}-families.fa" "${outdir}/"
    cp "${db}-families.stk" "${outdir}/" 2>/dev/null || true
    cp RM_*/consensi.fa.classified "${outdir}/" 2>/dev/null || true
    cp RM_*/families-classified.stk "${outdir}/" 2>/dev/null || true
    cp RM_*/rmod.log "${outdir}/" 2>/dev/null || true

    echo "Number of RepeatModeler families:"
    grep -c "^>" "${outdir}/${db}-families.fa"

    if [[ -s "${outdir}/consensi.fa.classified" ]]; then
        echo "Found classified consensus file:"
        ls -lh "${outdir}/consensi.fa.classified"
    else
        echo "WARNING: consensi.fa.classified was not found for ${genome_id}" >&2
        echo "Step 2 expects this file. Check RepeatModeler output in: ${workdir}" >&2
    fi

    cd "${PROJECT_DIR}"

    echo "Finished: ${genome_id}"
    echo "Finished time: $(date)"
    echo
done < "${GENOME_TABLE}"

echo "All genomes finished."