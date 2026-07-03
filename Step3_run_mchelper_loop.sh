#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${LOG_DIR}" "${MCHELPER_OUTDIR}"

if [[ ! -s "${MCHELPER_TABLE}" ]]; then
    echo "ERROR: MCHelper table not found: ${MCHELPER_TABLE}" >&2
    echo "Run 02_prepare_mchelper_table.sh first." >&2
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

load_mchelper_environment

while IFS=$'\t' read -r genome_id input_fa genome_fa; do
    if [[ ! -s "${input_fa}" ]]; then
        echo "ERROR: candidate FASTA not found or empty: ${input_fa}" >&2
        exit 1
    fi
    if [[ ! -s "${genome_fa}" ]]; then
        echo "ERROR: genome FASTA not found or empty: ${genome_fa}" >&2
        exit 1
    fi

    echo "Running MCHelper for ${genome_id}"
    python3 "${MCHELPER_PY}" \
        -r A \
        -l "${input_fa}" \
        --te_aid N \
        -v Y \
        -x "${MCHELPER_X}" \
        -e "${MCHELPER_EXTENSION}" \
        -t "${MCHELPER_THREADS}" \
        -o "${MCHELPER_OUTDIR}/MCHelper_output_${genome_id}" \
        -g "${genome_fa}" \
        --input_type fasta \
        -a F \
        -n "${genome_id}" \
        -b "${BUSCO_LINEAGE}"
done < "${MCHELPER_TABLE}"
