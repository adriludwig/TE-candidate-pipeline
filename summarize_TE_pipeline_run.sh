#!/usr/bin/env bash
set -euo pipefail

OUTDIR="${1:-run_basic_stats}"
mkdir -p "${OUTDIR}"

count_fasta_records() {
    local fasta="$1"
    if [[ -s "${fasta}" ]]; then
        grep -c '^>' "${fasta}" || true
    else
        echo 0
    fi
}

summarize_count_table() {
    local label="$1"
    local table="$2"

    awk -v label="${label}" '
    NR == 1 { next }
    $2 !~ /^[0-9]+$/ { next }
    {
        n++;
        sum += $2;
        if (min == "" || $2 < min) min = $2;
        if (max == "" || $2 > max) max = $2;
    }
    END {
        if (n == 0) {
            print label "_genomes\t0";
            print label "_total\t0";
            print label "_average_per_genome\tNA";
            print label "_min_per_genome\tNA";
            print label "_max_per_genome\tNA";
        } else {
            print label "_genomes\t" n;
            print label "_total\t" sum;
            print label "_average_per_genome\t" sum/n;
            print label "_min_per_genome\t" min;
            print label "_max_per_genome\t" max;
        }
    }' "${table}"
}

fasta_length_stats() {
    local fasta="$1"

    awk '
    BEGIN { n=0; len=0; sum=0; min=""; max=0 }
    /^>/ {
        if (n > 0) {
            sum += len;
            if (min == "" || len < min) min = len;
            if (len > max) max = len;
        }
        n++;
        len=0;
        next;
    }
    {
        gsub(/[ \t\r\n]/, "");
        len += length($0);
    }
    END {
        if (n > 0) {
            sum += len;
            if (min == "" || len < min) min = len;
            if (len > max) max = len;
            print "num_seqs\t" n;
            print "sum_len\t" sum;
            print "min_len\t" min;
            print "avg_len\t" sum/n;
            print "max_len\t" max;
        } else {
            print "num_seqs\t0";
            print "sum_len\t0";
            print "min_len\tNA";
            print "avg_len\tNA";
            print "max_len\tNA";
        }
    }' "${fasta}"
}

echo -e "metric\tvalue" > "${OUTDIR}/summary.tsv"

echo -e "genome_id\trepeatmodeler_consensi" > "${OUTDIR}/repeatmodeler_consensi_counts.tsv"
find repeatmodeler_more_genomes -name 'consensi.fa.classified' | sort | while read -r f; do
    genome="$(basename "$(dirname "${f}")")"
    n="$(count_fasta_records "${f}")"
    echo -e "${genome}\t${n}"
done >> "${OUTDIR}/repeatmodeler_consensi_counts.tsv"

echo -e "genome_id\tpre_mchelper_candidates" > "${OUTDIR}/pre_mchelper_candidate_counts.tsv"
find TE_candidate_screen_original_headers -name '*.new_TE_candidates.fa' | sort | while read -r f; do
    genome="$(basename "${f}" .new_TE_candidates.fa)"
    n="$(count_fasta_records "${f}")"
    echo -e "${genome}\t${n}"
done >> "${OUTDIR}/pre_mchelper_candidate_counts.tsv"

echo -e "genome_id\tmchelper_refined_candidates" > "${OUTDIR}/mchelper_refined_candidate_counts.tsv"
find MCHelper_newTEs -name 'curated_sequences_NR.fa' | sort | while read -r f; do
    genome="$(basename "$(dirname "${f}")")"
    genome="${genome#MCHelper_output_}"
    n="$(count_fasta_records "${f}")"
    echo -e "${genome}\t${n}"
done >> "${OUTDIR}/mchelper_refined_candidate_counts.tsv"

if [[ -s config/genomes.tsv ]]; then
    echo -e "input_genomes\t$(wc -l < config/genomes.tsv | tr -d ' ')" >> "${OUTDIR}/summary.tsv"
fi

summarize_count_table "repeatmodeler_consensi" "${OUTDIR}/repeatmodeler_consensi_counts.tsv" >> "${OUTDIR}/summary.tsv"
summarize_count_table "pre_mchelper_candidates" "${OUTDIR}/pre_mchelper_candidate_counts.tsv" >> "${OUTDIR}/summary.tsv"
summarize_count_table "mchelper_refined_candidates" "${OUTDIR}/mchelper_refined_candidate_counts.tsv" >> "${OUTDIR}/summary.tsv"

final_fa="final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa"
if [[ -s "${final_fa}" ]]; then
    fasta_length_stats "${final_fa}" | sed 's/^/final_TE_/' >> "${OUTDIR}/summary.tsv"
else
    echo -e "final_TE_num_seqs\t0" >> "${OUTDIR}/summary.tsv"
    echo -e "final_TE_sum_len\t0" >> "${OUTDIR}/summary.tsv"
    echo -e "final_TE_min_len\tNA" >> "${OUTDIR}/summary.tsv"
    echo -e "final_TE_avg_len\tNA" >> "${OUTDIR}/summary.tsv"
    echo -e "final_TE_max_len\tNA" >> "${OUTDIR}/summary.tsv"
fi

echo "Summary written to: ${OUTDIR}/summary.tsv"
echo
column -t -s $'\t' "${OUTDIR}/summary.tsv" 2>/dev/null || cat "${OUTDIR}/summary.tsv"
