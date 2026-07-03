#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Check all required dependencies before running the pipeline
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/config.sh" ]]; then
    echo "ERROR: config.sh not found."
    exit 1
fi

source "${SCRIPT_DIR}/config.sh"

check_program() {
    local program="$1"

    if command -v "$program" >/dev/null 2>&1; then
        echo "  OK: $program"
    else
        echo "  MISSING: $program"
        MISSING=1
    fi
}

###############################################################################
# RepeatModeler environment
###############################################################################

echo
echo "======================================================"
echo "Checking RepeatModeler environment"
echo "======================================================"

load_repeatmodeler_environment

MISSING=0

check_program BuildDatabase
check_program RepeatModeler

if [[ $MISSING -eq 1 ]]; then
    echo
    echo "ERROR: RepeatModeler environment is incomplete."
    exit 1
fi

###############################################################################
# Filtering environment
###############################################################################

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
check_program python3

if [[ $MISSING -eq 1 ]]; then
    echo
    echo "ERROR: Filtering environment is incomplete."
    exit 1
fi
###############################################################################
# MCHelper environment
###############################################################################

echo
echo "======================================================"
echo "Checking MCHelper environment"
echo "======================================================"

load_mchelper_environment

MISSING=0

check_program python3

if [[ -f "${MCHELPER_PY}" ]]; then

    echo "  OK: MCHelper.py (${MCHELPER_PY})"

else

    echo "  MISSING: MCHelper.py (${MCHELPER_PY})"

    MISSING=1

fi

if [[ $MISSING -eq 1 ]]; then
    echo
    echo "ERROR: MCHelper environment is incomplete."
    exit 1
fi
###############################################################################
# Finished
###############################################################################

echo
echo "======================================================"
echo "All required dependencies were found."
echo "The pipeline is ready to run."
echo "======================================================"
