# TE Candidate Discovery Pipeline

## Pipeline overview

``` mermaid
flowchart LR
    A[Genome assemblies] --> B[RepeatModeler]
    B --> C[Remove known TEs using curated library]
    C --> D[MCHelper]
    D --> E[Merge curated candidates]
    E --> F[CD-HIT-EST]
    F --> G[BLASTN RepBase]
    F --> H[BLASTX TE peptides]
    G --> I[Final candidate TE library]
    H --> I
```
# TE Candidate Discovery Pipeline

## Introduction

Building a comprehensive transposable element (TE) library is a critical first step for accurate genome annotation and evolutionary analyses. 
Although RepeatModeler is widely used for de novo TE discovery, its output typically contains a mixture of known TE families, 
fragmented consensus sequences, gene fragments, simple repeats, and other non-TE sequences. Consequently, substantial manual curation is usually required before the resulting library can be used for RepeatMasker or comparative analyses. The objective of this workflow is not to replace expert curation, but to substantially reduce the number of sequences requiring manual inspection while maximizing the recovery of bona fide TE families.

This pipeline was developed to automate the identification of high-confidence candidate TE families across multiple genome assemblies of the same species while minimizing the amount of manual curation required, raather than attempting to recover every possible repetitive sequence.

In addition, by analysing multiple genome assemblies simultaneously, the pipeline aims to recover a good consensus sequence for each TE family present in the species rather then a consensus for each strain. Because the resulting library represents species-level consensus sequences rather than strain-specific variants, it is particularly well suited for genome annotation and comparative analyses across multiple assemblies. However, analyses that rely on precise sequence divergence from strain-specific consensuses, such as RepeatMasker landscape analyses used to infer the relative ages of TE insertions, may be influenced by this approach.

The pipeline combines four complementary strategies:

1. **RepeatModeler** performs de novo repeat discovery independently in each genome.
2. Newly generated consensus sequences are compared against a curated species-specific TE library to remove families that have already been described.
3. The remaining candidates are analysed with **MCHelper**, which extends consensus sequences, reconstructs TE boundaries, removes obvious false positives, and performs structural annotation.
4. Curated candidates from all genomes are merged, dereplicated, and finally validated through nucleotide similarity (RepBase) and protein similarity (TE peptide database), producing a conservative set of candidate TE families suitable for manual inspection and incorporation into a curated TE library.

By analysing multiple genomes simultaneously, the pipeline increases the probability of recovering TE families that may be absent, fragmented, or poorly assembled in any individual genome while avoiding redundant manual inspection of the same family recovered independently from different assemblies.

## Pipeline assumptions

This workflow is intended for analyses of multiple genome assemblies belonging to the same species.

The pipeline assumes that:

- a curated TE library already exists for the species (This can be obtained from Repbase depending on the species. In this case, LTRs should be joined to the internal region)
- RepeatModeler consensus sequences are frequently fragmented or incomplete relative to curated TE consensuses;
- canonical TE families are expected to retain detectable nucleotide and/or protein similarity to previously described TEs;
- the objective is to expand an existing curated TE library, identifying bona-fide TEs rather than discover every repetitive sequence present in the genome.

Consequently, the pipeline adopts a conservative strategy. Candidate sequences lacking detectable similarity to known TE nucleotide or protein sequences are excluded from the final library. While some of these sequences may represent genuine non-canonical TEs, demonstrating their transposable nature generally requires extensive manual investigation and falls outside the scope of this automated workflow.

## Required data

This pipeline identifies candidate transposable element (TE) sequences from genome assemblies that are not already represented in an existing curated TE library.

The pipeline starts from:

1. genome FASTA files;
2. a curated TE library for the species or species group;
3. a RepBase nucleotide library for final BLASTN searches;
4. a TE peptide library, such as RepeatPeps.lib, for final BLASTX searches;
5. a BUSCO lineage suitable for the organism being analysed.

The final output is:

```text
final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa
```

## Workflow Summary

The pipeline runs these steps:

1. Prepare a genome table from the genome FASTA files.
2. Run RepeatModeler for each genome.
3. Remove RepeatModeler consensus sequences already represented in the curated TE library.
4. Prepare the MCHelper input table.
5. Run MCHelper for each genome-specific candidate FASTA.
6. Merge MCHelper outputs.
7. Remove redundant candidate sequences with CD-HIT-EST.
8. Search candidates against RepBase nucleotide sequences and TE peptides.
9. Write the final FASTA for manual inspection.

## Dependencies

The pipeline expects the following tools to be available through the environments defined in `config.sh`.

### RepeatModeler Step

Required:

- RepeatModeler
- BuildDatabase
- RepeatMasker
- RMBlast

Optional, only if `REPEATMODELER_USE_LTRSTRUCT="yes"`:

- LTRStruct-compatible RepeatModeler installation
- Any LTR-related tools required by that installation, such as GenomeTools, LTR_retriever, MAFFT, or TRF

RepeatModeler versions use different thread options:

- RepeatModeler 2.0.3 and older: `REPEATMODELER_THREADS_OPTION="-pa"`
- RepeatModeler 2.0.4 and newer: `REPEATMODELER_THREADS_OPTION="-threads"`

Check the version before running:

```bash
RepeatModeler -h | head
```

### Filtering Steps

Required for Step 2 and Step 4:

- BLAST+
- SeqKit
- CD-HIT

These tools are used for BLAST searches, FASTA extraction, BLAST database creation, and redundancy reduction.

### MCHelper Step

Required:

- MCHelper
- Python environment required by MCHelper
- BUSCO lineage appropriate for the species being analysed

For example, an *Aspergillus* analysis should use a fungal BUSCO lineage such as Eurotiales, not an animal lineage.

### Reference Files

Required input reference files:

- curated TE library for the species or species group
- RepBase nucleotide library for final BLASTN searches
- TE peptide library, such as `RepeatPeps.lib`, for final BLASTX searches
- BUSCO HMM lineage file for MCHelper

### SLURM Mode

The SLURM execution mode also requires the `sbatch` command and a working SLURM scheduler.

## Installation

Clone the repository:

```bash

git clone https://github.com/adriludwig/TE-candidate-pipeline.git
cd TE-candidate-pipeline

```
## Repository Layout

After cloning the repository, the directory should look like:

```text
TE-candidate-pipeline/
├── README.md
├── config.sh
├── check_dependencies.sh
├── run_TE_pipeline.sh
├── 00_prepare_genome_table.sh
├── 02_prepare_mchelper_table.sh
├── Step1_run_repeatmodeler_loop.sh
├── Step2_run_TE_candidates_original_headers.sh
├── Step3_run_mchelper_loop.sh
├── Step4_run_final_TE_filter_after_MCHelper.sh
├── TE_candidate_pipeline_original_headers.sh
└── slurm/
    ├── README.md
    ├── run_pipeline_slurm.sh
    ├── Step1_run_repeatmodeler_array.slurm
    ├── Step2_run_TE_candidates_original_headers.slurm
    ├── Step3_run_mchelper_array.slurm
    └── Step4_run_final_TE_filter_after_MCHelper.slurm
```

Input genomes, the curated TE library and the required databases can be stored anywhere on your system. Their locations should be specified in `config.sh`.

## Configure the Pipeline

Edit `config.sh` before running.

The main paths to check are:

```bash
GENOME_DIR="${PROJECT_DIR}"
GENOME_GLOB="*.fna"
GENOME_SUFFIX=".fna"

CURATED_TE_LIBRARY="${PROJECT_DIR}/Curated_TE_lib1.0.fa"
BUSCO_LINEAGE="/path_to_busco/lineages/diptera_odb10.hmm"
MCHELPER_PY="/path_to_MCHelper/MCHelper.py"

REPBASE_NT_FASTA="${PROJECT_DIR}/db/RepBase31.06.fasta/RepBase31.06.fasta"
TE_PEP_FASTA="${PROJECT_DIR}/db/RepeatPeps.lib"
```

If your genomes are already stored somewhere else, change only `GENOME_DIR`:

```bash
GENOME_DIR="/path/to/genome_fastas"
```

If your genome names have a longer suffix, adjust both `GENOME_GLOB` and `GENOME_SUFFIX`.

Example:

```bash
GENOME_GLOB="*_renamed_only_chrom.fna"
GENOME_SUFFIX="_renamed_only_chrom.fna"
```

For this file:

```text
GCA_020501695_renamed_only_chrom.fna
```

the genome ID will be:

```text
GCA_020501695
```

## Configure Software Environments

Edit the environment names or paths in `config.sh`:

```bash
REPEATMODELER_ENV="repeatmodeler"
FILTERING_ENV="te_filtering"
MCHELPER_ENV="mchelper"
```

The environment loading functions are also in `config.sh`:

```bash
load_repeatmodeler_environment() {
    set +u
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$REPEATMODELER_ENV"
    set -u
}
```

Use the same pattern for the filtering and MCHelper environments. The `set +u` and `set -u` lines are intentional because some conda activation scripts use variables that may be undefined under strict Bash mode.


## Verify dependencies (recommended)

Before running the pipeline, verify that all required software and environments are correctly configured:

```bash
bash check_dependencies.sh
```

If all dependencies are available, you should see:

```text
All required dependencies were found.
The pipeline is ready to run.
```

## Run the Pipeline

The repository supports two execution modes.

### Local Bash Mode

Use this mode for small tests, interactive compute nodes, or clusters where you do not want to submit SLURM jobs.

```bash
bash run_TE_pipeline.sh
```

### SLURM Mode

Use this mode on SLURM clusters. The launcher submits RepeatModeler and MCHelper as arrays and submits later steps with job dependencies.

```bash
bash slurm/run_pipeline_slurm.sh
```

SLURM resources are configured in the `SLURM settings` section of `config.sh`. The SLURM scripts are examples and may require adaptation to local HPC policies, for example account names, QoS names, modules, or partition names.

Both execution modes write logs in:

```text
logs/
```

SLURM job logs are written in:

```text
logs/slurm/
```

The pipeline creates these output directories:

```text
config/
logs/
repeatmodeler_more_genomes/
TE_candidate_screen_original_headers/
MCHelper_newTEs/
final_TE_candidates_after_MCHelper/
```

## Step Outputs

### Step 0: Genome Table

Output:

```text
config/genomes.tsv
```

Columns:

```text
genome_id    genome_fasta_path
```

### Step 1: RepeatModeler

Output per genome:

```text
repeatmodeler_more_genomes/<genome_id>/<genome_id>_db-families.fa
repeatmodeler_more_genomes/<genome_id>/consensi.fa.classified
repeatmodeler_more_genomes/<genome_id>/rmod.log
```

### Step 2: Remove Known TE Families

Step 2 compares each RepeatModeler `consensi.fa.classified` file against the curated TE library with BLASTN.

Thresholds are controlled in `config.sh`:

```bash
KNOWN_TE_MIN_IDENTITY="80"
KNOWN_TE_MIN_QCOV="50"
KNOWN_TE_MIN_LENGTH="80"
```

Outputs:

```text
TE_candidate_screen_original_headers/<genome_id>.new_TE_candidates.fa
TE_candidate_screen_original_headers/<genome_id>.known_TE_hits.ids
TE_candidate_screen_original_headers/<genome_id>.vs_curated_library.blastn.tsv
TE_candidate_screen_original_headers/summary.tsv
```

### Step 3: MCHelper

MCHelper input table:

```text
config/mchelper_inputs.tsv
```

Columns:

```text
genome_id    candidate_fasta    genome_fasta
```

Expected output per genome:

```text
MCHelper_newTEs/MCHelper_output_<genome_id>/curated_sequences_NR.fa
```

MCHelper extension parameters are controlled in `config.sh`:

```bash
MCHELPER_X="2"
MCHELPER_EXTENSION="2000"
```

### Step 4: Final BLAST Filter

Step 4:

1. concatenates all MCHelper `curated_sequences_NR.fa` files;
2. prefixes FASTA headers with the genome ID;
3. removes redundant candidate sequences with CD-HIT-EST;
4. builds BLAST databases if they are missing;
5. runs BLASTN against the RepBase nucleotide library;
6. runs BLASTX against the TE peptide library;
7. keeps candidates with at least one hit passing `FINAL_BLAST_EVALUE`.

The final Step 4 retention criterion is e-value only:

```bash
FINAL_BLAST_EVALUE="1e-10"
```

No identity, coverage, or alignment-length filters are applied in Step 4.

Final output:

```text
final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa
```

## Quick Checks

Check the genome table:

```bash
column -t config/genomes.tsv | less -S
```

Check Step 2 summary:

```bash
column -t TE_candidate_screen_original_headers/summary.tsv | less -S
```

Check MCHelper input table:

```bash
column -t config/mchelper_inputs.tsv | less -S
```

Count final candidates:

```bash
grep -c "^>" final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa
```

## Final curation

The purpose of this pipeline is to identify **high-confidence candidate TE families** that are absent from an existing curated TE library. Although the workflow applies multiple filtering and validation steps, the final FASTA (`final_potential_new_TEs.fa`) should be considered a collection of **candidate** TEs rather than a finished TE library.

Recommended validation steps include:

1. **Inspect TE structure**

   - Use **TE-Aid** to visualize the candidate, inspect its genomic distribution, evaluate terminal repeats (TIRs or LTRs), target site duplications (TSDs), and coding potential.

2. **Search for conserved protein domains**

   - Analyse predicted ORFs using **NCBI CD-Search** (or an equivalent conserved domain database) to identify domains characteristic of transposable elements (e.g. reverse transcriptase, integrase, RNase H, transposase, endonuclease, helicase).

3. **Compare with known TE families**

   - Search the candidate against RepBase, Dfam, or other TE databases to determine whether it represents a highly divergent member of a known family or a potentially novel family.

4. **Verify TE classification**

   - Although MCHelper provides an initial structural classification, this assignment should always be manually confirmed. In some cases, MCHelper may assign an incorrect order or superfamily. Structural features, conserved domains, and sequence similarity should all be considered before assigning a final classification.


Only candidates confirmed as bona fide TEs should be added to the original curated TE library. The resulting updated library can then be used for downstream applications such as genome annotation.

## Limitations

This pipeline is designed to identify canonical TE families supported by nucleotide and/or protein homology.

Highly divergent or non-canonical TEs lacking detectable similarity to known TE sequences may not be retained. Such elements require dedicated manual investigation and are outside the scope of this workflow.

## References

This pipeline relies on the following softwares:
| Software | Repository / Website |
|-----------|----------------------|
| RepeatModeler | https://github.com/Dfam-consortium/RepeatModeler |
| MCHelper | https://github.com/GonzalezLab/MCHelper |
| BLAST+ | https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+ |
| CD-HIT | https://github.com/weizhongli/cdhit |
| SeqKit | https://bioinf.shenwei.me/seqkit |
| BUSCO | https://busco.ezlab.org |
