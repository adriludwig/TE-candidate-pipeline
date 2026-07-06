#!/usr/bin/env bash
set -euo pipefail

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SLURM_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

if [[ ! -f "${SLURM_DIR}/config.sh" ]]; then
    echo "ERROR: slurm/config.sh not found." >&2
    exit 1
fi

source "${SLURM_DIR}/config.sh"

check_program() {
    local program="$1"

    if command -v "${program}" >/dev/null 2>&1; then
        echo "  OK: ${program}"
    else
        echo "  MISSING: ${program}"
        MISSING=1
    fi
}

echo
echo "======================================================"
echo "Checking SLURM command"
echo "======================================================"

MISSING=0
check_program sbatch

if [[ "${MISSING}" -eq 1 ]]; then
    echo
    echo "ERROR: SLURM command check failed."
    exit 1
fi

echo
echo "======================================================"
echo "Checking RepeatModeler container"
echo "======================================================"

load_repeatmodeler_environment

MISSING=0
check_program "${TETOOLS_CONTAINER_CMD}"

if [[ -s "${TETOOLS_SIF}" ]]; then
    echo "  OK: TETools image (${TETOOLS_SIF})"
else
    echo "  MISSING: TETools image (${TETOOLS_SIF})"
    MISSING=1
fi

builddatabase_help="$("${TETOOLS_CONTAINER_CMD}" exec "${TETOOLS_SIF}" BuildDatabase 2>&1 || true)"
if grep -q "BuildDatabase" <<< "${builddatabase_help}"; then
    echo "  OK: BuildDatabase inside container"
else
    echo "  MISSING: BuildDatabase inside container"
    MISSING=1
fi

repeatmodeler_help="$("${TETOOLS_CONTAINER_CMD}" exec "${TETOOLS_SIF}" RepeatModeler 2>&1 || true)"
if grep -q "RepeatModeler" <<< "${repeatmodeler_help}"; then
    echo "  OK: RepeatModeler inside container"
else
    echo "  MISSING: RepeatModeler inside container"
    MISSING=1
fi

if [[ "${MISSING}" -eq 1 ]]; then
    echo
    echo "ERROR: RepeatModeler container check failed."
    exit 1
fi

echo
echo "======================================================"
echo "Checking filtering environment"
echo "======================================================"

load_filtering_environment

MISSING=0
check_program makeblastdb
check_program blastn
check_program blastx
check_program cd-hit-est
check_program seqkit

if [[ "${MISSING}" -eq 1 ]]; then
    echo
    echo "ERROR: filtering environment check failed."
    exit 1
fi

echo
echo "======================================================"
echo "Checking MCHelper environment"
echo "======================================================"

load_mchelper_environment

MISSING=0
check_program python3

if [[ -s "${MCHELPER_PY}" ]]; then
    echo "  OK: MCHelper.py (${MCHELPER_PY})"
else
    echo "  MISSING: MCHelper.py (${MCHELPER_PY})"
    MISSING=1
fi

if [[ ! -e "${BUSCO_LINEAGE}" ]]; then
    echo "  MISSING: BUSCO lineage (${BUSCO_LINEAGE})"
    MISSING=1
else
    echo "  OK: BUSCO lineage (${BUSCO_LINEAGE})"
fi

if [[ "${MISSING}" -eq 1 ]]; then
    echo
    echo "ERROR: MCHelper environment check failed."
    exit 1
fi

echo
echo "======================================================"
echo "All required SLURM pipeline dependencies were found."
echo "The SLURM pipeline is ready to run."
echo "======================================================"
