#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${LOG_DIR}" "${CANDIDATE_OUTDIR}"
cd "${PROJECT_DIR}"

load_filtering_environment

"${SCRIPT_DIR}/TE_candidate_pipeline_original_headers.sh" \
    --input_dir "${REPEATMODELER_OUTDIR}" \
    --library "${CURATED_TE_LIBRARY}" \
    --output_dir "${CANDIDATE_OUTDIR}" \
    --consensi_name "consensi.fa.classified" \
    --identity "${KNOWN_TE_MIN_IDENTITY}" \
    --coverage "${KNOWN_TE_MIN_QCOV}" \
    --min_length "${KNOWN_TE_MIN_LENGTH}" \
    --threads "${FILTER_THREADS}"
