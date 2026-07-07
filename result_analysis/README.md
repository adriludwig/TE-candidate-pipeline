# Result Analysis Utilities

This folder contains optional scripts for inspecting and summarising the final
candidate TE sequences produced by the pipeline. They are intended for downstream inspection, manual curation, and reporting of pipeline
results.

## TE-Aid Inspection of Final Candidates

The script `run_te_aid_on_final_candidates.sh` runs TE-Aid on each sequence in:

```text
final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa
```

TE-Aid is useful at this stage because the final FASTA still contains
candidate TE sequences. 

TE-Aid can help inspect:

- terminal repeats;
- coding potential;
- number of genomic copies and divergence of copies from the consensus;
- whether the sequence appears complete enough.

## Important Input Requirement

TE-Aid must be run against the genome where each candidate was recovered.

This pipeline prefixes final candidate FASTA headers with the source genome ID.
The TE-Aid helper script uses that genome ID to find the corresponding genome
FASTA file in `GENOME_DIR`.

For this to work, genome FASTA files must be named consistently with the genome
IDs used by the pipeline.

Example:

```text
Final candidate header:
>GCA_001643665|candidate_1

Expected genome file when GENOME_SUFFIX=".fna":
GENOME_DIR/GCA_001643665.fna
```

If your genome files use another suffix, edit `GENOME_SUFFIX` at the top of the
script.

## How to Run

Copy or keep the script in the main pipeline output directory and edit the
settings at the top:

```bash
INPUT_FASTA="final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa"
GENOME_DIR="/path/to/genome_fastas"
GENOME_SUFFIX=".fna"
TEAID="/path/to/TE-Aid/TE-Aid"
OUTDIR="te_aid_final_candidates"
```

If TE-Aid needs a conda or micromamba environment, edit:

```bash
load_teaid_environment()
```

Then run:

```bash
bash result_analysis/run_te_aid_on_final_candidates.sh
```

The script creates:

```text
te_aid_final_candidates/
├── single_fastas/
└── te_aid_run_summary.tsv
```

`single_fastas/` contains one FASTA file per final candidate TE sequence.

`te_aid_run_summary.tsv` records which genome FASTA was used for each candidate
and whether TE-Aid was run successfully or the matching genome was missing.

## Notes

- This script assumes final FASTA headers retain the source genome ID at the
  beginning of the sequence name.
- If candidates were renamed manually, check that the source genome ID is still
  present in the header.
- TE-Aid output should be manually inspected before any candidate is added to a
  curated TE library.
