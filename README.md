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

## Contents

- [Pipeline overview](#pipeline-overview)
- [Introduction](#introduction)
- [Required data](#required-data)
- [Workflow summary](#workflow-summary)
- [Dependencies](#dependencies)
- [Installation](#installation)
- [Repository layout](#repository-layout)
- [Configure the pipeline](#configure-the-pipeline)
- [Configure software environments](#configure-software-environments)
- [Verify dependencies](#verify-dependencies-recommended)
- [Run the pipeline](#run-the-pipeline)
- [Step outputs](#step-outputs)
- [Final curation](#final-curation)
- [Limitations](#limitations)
- [References](#references)

## Introduction

Building a comprehensive transposable element (TE) library is a critical first step for accurate genome annotation. Although RepeatModeler is widely used for de novo TE discovery, its output typically contains a mixture of known TE families, fragmented consensus sequences, gene fragments, simple repeats, and other non-TE sequences. Consequently, substantial manual curation is usually required before the resulting library can be used for proper annotation of the TEs in the genomes. 

This pipeline was developed to automate the identification of high-confidence candidate TE families across multiple genome assemblies of the same species while minimising the amount of manual curation required. The final output is a FASTA library of candidate TEs that should be manually inspected and validated before being incorporated into a curated TE library for downstream analysis.

Analysing multiple genomes also provides a more comprehensive representation of the mobilome present in the species pangenome, increasing the probability of recovering TE families that may be absent, fragmented, or poorly assembled in any individual genome while avoiding redundant manual inspection of the same family recovered independently from different assemblies.

This approach is well suited for genome annotation. However, analyses that rely on precise sequence divergence, such as RepeatMasker landscape analyses used to infer the relative ages of TE insertions, may be influenced by this approach.

Moreover, the pipeline adopts a conservative strategy. Candidate sequences lacking detectable nucleotide or protein similarity to previously described TEs are excluded from the final library.  This is because it is unlikely that a bona fide canonical TE would lack detectable similarity to any known TE at both the nucleotide and protein levels Although some of these candidates may represent genuine non-canonical or highly divergent TEs, such elements are considered rare, and demonstrating their transposable nature generally requires extensive manual curation.

The pipeline combines four complementary strategies:

1. **RepeatModeler** performs de novo repeat discovery independently in each genome. 
2. Newly generated consensus sequences are compared against a curated species-specific TE library to remove families that have already been described. 
3. The remaining candidates are analysed with **MCHelper**, which extends consensus sequences, reconstructs TE boundaries, removes obvious false positives, and performs structural annotation.
4. Curated candidates from all genomes are merged, dereplicated, and finally validated through nucleotide similarity (RepBase) and protein similarity (TE peptide database), producing a conservative set of candidate TE families suitable for manual inspection and incorporation into a curated TE library.


## Required data

This pipeline identifies candidate transposable element (TE) sequences from genome assemblies that are not already represented in an existing curated TE library.

The pipeline starts from:

1. Genome FASTA files;
2. A curated TE library for the species or species group:
This can be obtained from Repbase depending on the species. In this case, LTRs should be joined to the internal region. For species without an available curated TE library, this filtering step can be effectively skipped by providing a FASTA file containing a single dummy sequence. In this case, all RepeatModeler candidate families are retained for downstream analyses. 
  Example:
```fasta
>dummy_TE
NNNNNNNNNN
```
3. A RepBase nucleotide library for final BLASTN searches: 
It can be obtained here: https://www.girinst.org/server/RepBase/index.php
4. A TE peptide library, such as RepeatPeps.lib, for final BLASTX searches:
It can be obtained here: https://raw.githubusercontent.com/rmhubley/RepeatMasker/master/Libraries/RepeatPeps.lib
5. A BUSCO lineage suitable for the organism being analysed.

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

The final output is:

```text
final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa
```

## Dependencies

The pipeline expects the following tools to be available through the environments defined in `config.sh`.

### RepeatModeler Step

Required:

- RepeatModeler and its dependencies
https://github.com/Dfam-consortium/RepeatModeler

LTRStruct should be installed to use `REPEATMODELER_USE_LTRSTRUCT="yes"`:

RepeatModeler versions use different thread options:
- RepeatModeler 2.0.3 and older: `REPEATMODELER_THREADS_OPTION="-pa"`
- RepeatModeler 2.0.4 and newer: `REPEATMODELER_THREADS_OPTION="-threads"`

Check the version before running:

### Filtering Steps

Required for Step 2 and Step 4:
- BLAST+
- SeqKit
- CD-HIT

These tools are used for BLAST searches, FASTA extraction, BLAST database creation, and redundancy reduction.

### MCHelper Step
https://github.com/GonzalezLab/MCHelper

Required:

- MCHelper
- Python environment required by MCHelper
- BUSCO lineage appropriate for the species being analysed


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

Adjust the genome file suffix; `GENOME_GLOB` and `GENOME_SUFFIX`.


## Configure Software Environments

Edit the environment names or paths in `config.sh`


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

```bash
bash run_TE_pipeline.sh
```

### SLURM Mode

```bash
bash slurm/run_pipeline_slurm.sh
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

## Final curation

The purpose of this pipeline is to identify **high-confidence candidate TE families** that are absent from an existing curated TE library. Although the workflow applies multiple filtering and validation steps, the final FASTA (`final_potential_new_TEs.fa`) should be considered a collection of **candidate** TEs rather than a finished TE library.

Recommended validation steps include:

1. **Inspect TE structure**

   - Use **TE-Aid** to visualise the candidate, inspect its genomic distribution, evaluate terminal repeats (TIRs or LTRs), target site duplications (TSDs), and coding potential.
   - If the TE consensus is still not complete, the pipeline can be rerun, excluding step 1 (repeatmodeler) and increasing the size of flanking regions or the number of iterative extensions for MCHelper. A manual consensus retrieval for specific consensus can also be obtained manually following Goubert et al 2022 (https://pmc.ncbi.nlm.nih.gov/articles/PMC8969392/).
   

2. **Search for conserved protein domains**

   - Analyse predicted ORFs using **NCBI CD-Search** (or an equivalent conserved domain database) to identify domains characteristic of transposable elements (e.g. reverse transcriptase, integrase, RNase H, transposase, endonuclease, helicase).

4. **Compare with known TE families**

   - Search the candidate against RepBase, Dfam, or other TE databases to determine whether it represents a highly divergent member of a known family or a potentially novel family.

5. **Verify TE classification**

   - Although MCHelper provides an initial structural classification, this assignment should always be manually confirmed. In some cases, MCHelper may assign an incorrect order or superfamily. Structural features, conserved domains, and sequence similarity should all be considered before assigning a final classification. 


Only candidates confirmed as bona fide TEs should be added to the original curated TE library. The resulting updated library can then be used for downstream applications such as genome annotation.

## Limitations

This pipeline is designed to identify canonical TE families supported by nucleotide and/or protein similarity.

Highly divergent or non-canonical TEs lacking detectable similarity to known TE sequences may not be retained. Such elements require dedicated manual investigation and are outside the scope of this workflow.

## References

This pipeline relies on the following software:
| Software | Repository / Website |
|-----------|----------------------|
| RepeatModeler | https://github.com/Dfam-consortium/RepeatModeler |
| MCHelper | https://github.com/GonzalezLab/MCHelper |
| BLAST+ | https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+ |
| CD-HIT | https://github.com/weizhongli/cdhit |
| SeqKit | https://bioinf.shenwei.me/seqkit |
| BUSCO | https://busco.ezlab.org |
