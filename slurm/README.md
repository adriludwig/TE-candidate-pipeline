# Running the Pipeline with SLURM

This folder contains an independent SLURM version of the TE candidate discovery
pipeline.

These SLURM scripts were adapted for the cluster environment used during testing.
Software modules, micromamba paths, container paths, environment names, file
paths, and SLURM resource settings may not match other HPC systems.

Before running the pipeline on another cluster, users should review and edit the
files in the `slurm/` folder as needed.

If you run the SLURM version, edit and use only the files inside `slurm/`.
The non-SLURM scripts in the main folder are not required.

## Files

```text
slurm/
├── README.md
├── config.sh
├── check_dependencies.sh
├── 00_prepare_genome_table.sh
├── Step1_run_repeatmodeler.slurm.sh
├── Step2_run_TE_candidates_original_headers.slurm.sh
├── TE_candidate_pipeline_original_headers.sh
├── 02_prepare_mchelper_table.sh
├── Step3_run_mchelper.slurm.sh
├── Step4_run_final_TE_filter_after_MCHelper.slurm.sh
└── run_pipeline_slurm.sh
```

## What to Edit

Edit the SLURM configuration file:

```bash
slurm/config.sh
```

This file contains:

- input genome pattern;
- curated TE library path;
- BUSCO lineage path;
- MCHelper path;
- RepBase nucleotide FASTA path;
- TE peptide FASTA path;
- RepeatModeler, filtering, MCHelper, and CD-HIT parameters;
- cluster-specific software loading commands.

Edit SLURM resources in the header of each `.slurm.sh` script:

```bash
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=48:00:00
```

## How to Run

Run all commands from the pipeline run directory, the same directory that
contains the `slurm/` folder.

### Option 1: run all steps sequentially

To run the full SLURM workflow one step at a time:

```bash
bash slurm/run_pipeline_slurm.sh
```

This runner uses `sbatch --wait`. It submits one SLURM job, waits until that job
finishes, and then starts the next step. If a step fails, the runner stops.
It runs `slurm/check_dependencies.sh` before preparing the genome table.

### Option 2: run each step manually

First check that the required programs and files are available:

```bash
bash slurm/check_dependencies.sh
```

Prepare the genome table:

```bash
bash slurm/00_prepare_genome_table.sh
```

Submit Step 1:

```bash
sbatch slurm/Step1_run_repeatmodeler.slurm.sh
```

Wait until Step 1 finishes successfully. Check:

```bash
squeue -u "$USER"
tail -n 80 logs/slurm/TE_step1_repeatmodeler_*.err
tail -n 80 logs/slurm/TE_step1_repeatmodeler_*.out
```

Submit Step 2:

```bash
sbatch slurm/Step2_run_TE_candidates_original_headers.slurm.sh
```

Wait until Step 2 finishes successfully, then prepare the MCHelper table:

```bash
bash slurm/02_prepare_mchelper_table.sh
```

Submit Step 3:

```bash
sbatch slurm/Step3_run_mchelper.slurm.sh
```

Wait until Step 3 finishes successfully, then submit Step 4:

```bash
sbatch slurm/Step4_run_final_TE_filter_after_MCHelper.slurm.sh
```

## Resume Behaviour

The scripts skip outputs that already exist:

- Step 1 skips a genome if `consensi.fa.classified` already exists.
- Step 2 skips if `TE_candidate_screen_original_headers/summary.tsv` exists.
- Step 3 skips a genome if `curated_sequences_NR.fa` already exists.
- Step 4 skips if `final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa`
  exists.

To rerun a step, remove the corresponding output folder or file before
submitting the step again.
