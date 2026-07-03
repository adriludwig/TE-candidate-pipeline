#!/usr/bin/env bash
# Configuration file for the TE candidate discovery pipeline.
#

VERSION="1.1"

###############################################################################
# Project directory
###############################################################################

# The pipeline uses one working directory for both input files and output files.
# Run the pipeline from the directory that contains:
#   - genome FASTA files
#   - curated TE library
#   - db/ folder with RepBase and TE peptide files
#   - pipeline scripts
#
# Output folders will also be created in this same directory.
PROJECT_DIR="$(pwd -P)"

###############################################################################
# Genome inputs
###############################################################################
#
# Default: genome FASTA files are expected in the same directory where you run
# the pipeline.
#
# If your genome FASTA files are stored in another directory, replace
# "${PROJECT_DIR}" with the full path to that directory.

GENOME_DIR="${PROJECT_DIR}"

# Edit GENOME_GLOB and GENOME_SUFFIX only if your genome files use a different
# naming pattern, for example "genome.fasta"
#
# For these names:
#   GENOME_GLOB finds all genome FASTA files.
#   GENOME_SUFFIX is removed from the file name to create the genome ID.
#   
GENOME_GLOB="*.fna" 
GENOME_SUFFIX=".fna"

###############################################################################
# TE libraries and MCHelper inputs
###############################################################################

# Curated TE library used in Step 2 to remove TE families that are already known.
# This can be obtained from Repbase depending on the species. In this case, LTRs should be
# joined to the internal region.
# Edit the file name for your curated library.
CURATED_TE_LIBRARY="${PROJECT_DIR}/Curated_TE_lib1.0.fa"

# BUSCO lineage used by MCHelper.
# Check the best BUSCO database to your species
#Example on how to obtain the BUSCO dataset for Drosophila
#wget https://busco-data.ezlab.org/v4/data/lineages/diptera_odb10.2020-08-05.tar.gz
#tar xvf diptera_odb10.2020-08-05.tar.gz
#cat diptera_odb10/hmms/*.hmm > diptera_odb10.hmm
#cd -

# Edit the path to busco.
BUSCO_LINEAGE="/path_to_busco/lineages/diptera_odb10.hmm"

# MCHelper script.
# Edit the path to MCHelper.py.
MCHELPER_PY="/path_to_MCHelper/MCHelper.py"

###############################################################################
# Reference files for final BLAST searches
###############################################################################

# RepBase nucleotide library used by BLASTN in the final filtering step.
# Edit this path if your RepBase file is stored somewhere else.
REPBASE_NT_FASTA="${PROJECT_DIR}/db/RepBase31.06.fasta/RepBase31.06.fasta"

# TE peptide library, for example RepeatPeps.lib, used by BLASTX in the final
# filtering step. Edit this path if your peptide file is stored somewhere else.
TE_PEP_FASTA="${PROJECT_DIR}/db/RepeatPeps.lib"

###############################################################################
# Output directories
###############################################################################

CONFIG_DIR="${PROJECT_DIR}/config"
LOG_DIR="${PROJECT_DIR}/logs"

GENOME_TABLE="${CONFIG_DIR}/genomes.tsv"
MCHELPER_TABLE="${CONFIG_DIR}/mchelper_inputs.tsv"

REPEATMODELER_OUTDIR="${PROJECT_DIR}/repeatmodeler_more_genomes"
CANDIDATE_OUTDIR="${PROJECT_DIR}/TE_candidate_screen_original_headers"
MCHELPER_OUTDIR="${PROJECT_DIR}/MCHelper_newTEs"
FINAL_OUTDIR="${PROJECT_DIR}/final_TE_candidates_after_MCHelper"

REPBASE_NT_DB_PREFIX="${FINAL_OUTDIR}/repbase_nt"
TE_PEP_DB_PREFIX="${FINAL_OUTDIR}/te_peptides"

###############################################################################
# Step 2: remove known TE consensus sequences
###############################################################################
#BLASTN thresholds used to identify TE consensus sequences already represented
# A minimum query coverage of 50% was chosen instead of the classical 80-80-80
# criterion because RepeatModeler frequently generates fragmented or partial
# consensus sequences. Since the curated library is assumed to contain more
# complete TE consensuses, a partial RepeatModeler consensus may still represent
# the same TE family even if it covers only part of the curated sequence.
# Therefore, candidates showing >=80% nucleotide identity over at least 50% of
# their own length are considered already represented in the curated library and
# are removed from further analyses.

KNOWN_TE_MIN_IDENTITY="80"
KNOWN_TE_MIN_QCOV="50"
KNOWN_TE_MIN_LENGTH="80"

###############################################################################
# Step 4: final BLAST filtering
###############################################################################
# After MCHelper, candidate sequences from all genomes are merged and
# dereplicated using CD-HIT-EST. Clustering is performed using an 80-80-80
# criterion (80% identity and at least 80% coverage of both the shorter and
# longer sequences) to collapse redundant representatives of the same TE family.
# The non-redundant candidates are then searched against RepBase (BLASTN) and a
# TE peptide database (BLASTX). Candidates with significant similarity to either
# database (E-value <= 1e-10) are retained as high-confidence TE candidates
# that will be further inspected.

# It is unlikely that bona fide canonical TEs would lack any detectable similarity 
# to previously described TE nucleotide or protein sequences. As the aim of this pipeline
# is to generate a curated library of bona fide TEs, only candidates supported by sequence 
# similarity are retained. Although some of these sequences could represent genuine
# non-canonical TEs, demonstrating their transposable nature would require extensive 
# manual investigation. 

FINAL_BLAST_EVALUE="1e-10"

CDHIT_IDENTITY="0.80"
CDHIT_SHORTER_COVERAGE="0.80"
CDHIT_LONGER_COVERAGE="0.80"

###############################################################################
# Thread settings
###############################################################################

REPEATMODELER_THREADS="16"
FILTER_THREADS="16"
MCHELPER_THREADS="16"

###############################################################################
# RepeatModeler settings
###############################################################################
#
# How RepeatModeler will be loaded.
#
# Use "environment" if RepeatModeler is installed in a conda/micromamba
# environment or is already available in your PATH.
#
# Use "singularity" only if your pipeline scripts were adapted to run
# RepeatModeler from a Singularity/Apptainer container.
REPEATMODELER_MODE="environment"

# RepeatModeler option used to set the number of CPU threads.
#
# RepeatModeler versions use different option names:
#   - RepeatModeler 2.0.3 and older: use "-pa"
#   - RepeatModeler 2.0.4 and newer: use "-threads"
#
# To check your version, run:
#   RepeatModeler -h | head
#
# Then set:
#   REPEATMODELER_THREADS_OPTION="-pa"       # for RepeatModeler 2.0.3 and older
#   REPEATMODELER_THREADS_OPTION="-threads"  # for RepeatModeler 2.0.4 and newer
REPEATMODELER_THREADS_OPTION="-pa"

# Whether to run RepeatModeler with LTR structural discovery.
#
# Use "yes" to add:
#   -LTRStruct
#
# Use "no" to run RepeatModeler without LTR structural discovery.
#
# LTRStruct may improve recovery and classification of LTR retrotransposons,
# but it increases runtime and may require additional LTR-related tools in the
# RepeatModeler environment.
REPEATMODELER_USE_LTRSTRUCT="yes"

###############################################################################
# MCHelper settings
###############################################################################

# MCHelper iteratively extends each candidate sequence by a fixed number of
# nucleotides on both sides to recover potentially missing TE boundaries.
#
# MCHelper parameter "-x": Number of extension iterations.
#
# MCHelper parameter "-e": Number of nucleotides added to each side of the 
# candidate sequence at each iteration.
#
# Total maximum extension = x * e bp on each side.
#
# Default values (2 * 2000 bp) generally allow recovery of TE termini for
# fragmented RepeatModeler consensus sequences while avoiding excessive
# extension into surrounding genomic regions.

MCHELPER_X="2"
MCHELPER_EXTENSION="2000"

###############################################################################
# SLURM settings
###############################################################################
# These values are used only by slurm/run_pipeline_slurm.sh.
# Leave SLURM_PARTITION empty to use the cluster default partition.
# Leave memory or time values empty to use the cluster defaults.
#
# ARRAY_CONCURRENCY controls how many array tasks can run at the same time.
# Example: ARRAY_CONCURRENCY="3" submits arrays as 1-N%3.
# Leave it empty to let SLURM use the cluster default.

SLURM_PARTITION=""

STEP1_CPUS=""
STEP1_MEM=""
STEP1_TIME=""

STEP2_CPUS=""
STEP2_MEM=""
STEP2_TIME=""

STEP3_CPUS=""
STEP3_MEM=""
STEP3_TIME=""

STEP4_CPUS=""
STEP4_MEM=""
STEP4_TIME=""

ARRAY_CONCURRENCY=""

###############################################################################
# Software environments
###############################################################################
# Each pipeline step is executed in its own conda/micromamba environment to
# avoid dependency conflicts between RepeatModeler, MCHelper and the filtering
# tools.
#
# Replace the example environment names below with the environments installed
# on your system.
REPEATMODELER_ENV="repeatmodeler"
FILTERING_ENV="te_filtering"
MCHELPER_ENV="mchelper"

load_repeatmodeler_environment() {
    set +u
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$REPEATMODELER_ENV"
    set -u
}

load_filtering_environment() {
    set +u
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$FILTERING_ENV"
    set -u
}

load_mchelper_environment() {
    set +u
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$MCHELPER_ENV"
    set -u
}
