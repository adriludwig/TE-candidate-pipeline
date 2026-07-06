#!/usr/bin/env bash
set -euo pipefail

SLURM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SLURM_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"
source "${SLURM_DIR}/config.sh"

mkdir -p "${CONFIG_DIR}" "${LOG_DIR}/slurm" "${REPEATMODELER_OUTDIR}" "${CANDIDATE_OUTDIR}" "${MCHELPER_OUTDIR}" "${FINAL_OUTDIR}"

if [[ ! -d "${GENOME_DIR}" ]]; then
    echo "ERROR: GENOME_DIR does not exist: ${GENOME_DIR}" >&2
    exit 1
fi

tmp_table="${GENOME_TABLE}.tmp"
: > "${tmp_table}"

while IFS= read -r genome_fa; do
    [[ -s "${genome_fa}" ]] || continue
    file_name="$(basename "${genome_fa}")"
    genome_id="${file_name}"
    if [[ -n "${GENOME_SUFFIX}" && "${genome_id}" == *"${GENOME_SUFFIX}" ]]; then
        genome_id="${genome_id%"${GENOME_SUFFIX}"}"
    else
        genome_id="${genome_id%.*}"
    fi
    printf "%s\t%s\n" "${genome_id}" "${genome_fa}" >> "${tmp_table}"
done < <(find "${GENOME_DIR}" -maxdepth 1 -type f -name "${GENOME_GLOB}" | sort)

mv "${tmp_table}" "${GENOME_TABLE}"

n_genomes="$(wc -l < "${GENOME_TABLE}" | tr -d ' ')"
if [[ "${n_genomes}" -eq 0 ]]; then
    echo "ERROR: no genomes found in ${GENOME_DIR} with pattern ${GENOME_GLOB}" >&2
    exit 1
fi

echo "Genome table: ${GENOME_TABLE}"
echo "Number of genomes: ${n_genomes}"
