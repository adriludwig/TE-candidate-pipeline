#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${CONFIG_DIR}" "${LOG_DIR}" "${MCHELPER_OUTDIR}"

tmp_table="${MCHELPER_TABLE}.tmp"
: > "${tmp_table}"

while IFS= read -r candidate_fa; do
    [[ -s "${candidate_fa}" ]] || continue
    genome_id="$(basename "${candidate_fa}" .new_TE_candidates.fa)"
    genome_fa="$(awk -F '\t' -v id="${genome_id}" '$1 == id {print $2; exit}' "${GENOME_TABLE}")"
    if [[ -z "${genome_fa}" || ! -s "${genome_fa}" ]]; then
        echo "WARNING: genome FASTA not found for ${genome_id}; skipping MCHelper input." >&2
        continue
    fi
    printf "%s\t%s\t%s\n" "${genome_id}" "${candidate_fa}" "${genome_fa}" >> "${tmp_table}"
done < <(find "${CANDIDATE_OUTDIR}" -maxdepth 1 -name "*.new_TE_candidates.fa" | sort)

mv "${tmp_table}" "${MCHELPER_TABLE}"

n_inputs="$(wc -l < "${MCHELPER_TABLE}" | tr -d ' ')"
if [[ "${n_inputs}" -eq 0 ]]; then
    echo "ERROR: no non-empty MCHelper candidate FASTA files found in ${CANDIDATE_OUTDIR}" >&2
    exit 1
fi

echo "MCHelper input table: ${MCHELPER_TABLE}"
echo "Number of MCHelper jobs: ${n_inputs}"
