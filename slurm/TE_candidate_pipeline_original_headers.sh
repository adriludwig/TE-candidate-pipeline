#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  TE_candidate_pipeline_original_headers.sh \
    --input_dir repeatmodeler_more_genomes \
    --library curated_TE_library.fa \
    --output_dir TE_candidate_screen \
    --consensi_name consensi.fa.classified \
    --identity 80 \
    --coverage 50 \
    --min_length 80 \
    --threads 8
USAGE
}

input_dir=""
library=""
output_dir=""
consensi_name="consensi.fa.classified"
identity="80"
coverage="50"
min_length="80"
threads="1"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input_dir) input_dir="$2"; shift 2 ;;
        --library) library="$2"; shift 2 ;;
        --output_dir) output_dir="$2"; shift 2 ;;
        --consensi_name) consensi_name="$2"; shift 2 ;;
        --identity) identity="$2"; shift 2 ;;
        --coverage) coverage="$2"; shift 2 ;;
        --min_length) min_length="$2"; shift 2 ;;
        --threads) threads="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ -z "${input_dir}" || -z "${library}" || -z "${output_dir}" ]]; then
    echo "ERROR: --input_dir, --library, and --output_dir are required." >&2
    usage >&2
    exit 1
fi

if [[ ! -d "${input_dir}" ]]; then
    echo "ERROR: input directory not found: ${input_dir}" >&2
    exit 1
fi

if [[ ! -s "${library}" ]]; then
    echo "ERROR: curated TE library not found or empty: ${library}" >&2
    exit 1
fi

mkdir -p "${output_dir}"

library_db="${output_dir}/curated_TE_library.blastdb"
if [[ ! -s "${library_db}.nsq" && ! -s "${library_db}.00.nsq" ]]; then
    makeblastdb -in "${library}" -dbtype nucl -out "${library_db}"
fi

summary="${output_dir}/summary.tsv"
printf "genome_id\tinput_consensi\tknown_TE_hits\tnew_TE_candidates\n" > "${summary}"

found_any="no"
while IFS= read -r consensi_fa; do
    found_any="yes"
    genome_id="$(basename "$(dirname "${consensi_fa}")")"
    blast_out="${output_dir}/${genome_id}.vs_curated_library.blastn.tsv"
    known_ids="${output_dir}/${genome_id}.known_TE_hits.ids"
    candidate_fa="${output_dir}/${genome_id}.new_TE_candidates.fa"

    echo "Processing ${genome_id}"
    blastn \
        -query "${consensi_fa}" \
        -db "${library_db}" \
        -out "${blast_out}" \
        -evalue 1e-10 \
        -dust no \
        -soft_masking false \
        -num_threads "${threads}" \
        -outfmt "6 qseqid sseqid pident length qlen slen qcovs evalue bitscore"

    awk -v min_id="${identity}" -v min_cov="${coverage}" -v min_len="${min_length}" \
        '($3 >= min_id) && ($4 >= min_len) && ($7 >= min_cov) {print $1}' \
        "${blast_out}" | sort -u > "${known_ids}"

    if [[ -s "${known_ids}" ]]; then
        seqkit grep -v -f "${known_ids}" "${consensi_fa}" > "${candidate_fa}"
    else
        cp "${consensi_fa}" "${candidate_fa}"
    fi

    n_input="$(grep -c "^>" "${consensi_fa}" || true)"
    n_known="$(wc -l < "${known_ids}" | tr -d ' ')"
    n_new="$(grep -c "^>" "${candidate_fa}" || true)"
    printf "%s\t%s\t%s\t%s\n" "${genome_id}" "${n_input}" "${n_known}" "${n_new}" >> "${summary}"
done < <(find "${input_dir}" -mindepth 2 -maxdepth 2 -name "${consensi_name}" | sort)

if [[ "${found_any}" == "no" ]]; then
    echo "ERROR: no ${consensi_name} files found under ${input_dir}" >&2
    exit 1
fi

echo "Summary written to: ${summary}"
