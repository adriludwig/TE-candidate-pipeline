# SLURM Execution Mode

This folder adds a SLURM execution mode for the TE candidate discovery pipeline.

The biological workflow is the same as the local mode:

```bash
bash run_TE_pipeline.sh
```

The SLURM mode is launched with:

```bash
bash slurm/run_pipeline_slurm.sh
```

## What the SLURM Launcher Does

The launcher submits the same pipeline steps using SLURM:

1. runs `00_prepare_genome_table.sh`;
2. submits Step 1 as a SLURM array over `config/genomes.tsv`;
3. submits Step 2 after Step 1 finishes;
4. runs `02_prepare_mchelper_table.sh` after Step 2 finishes;
5. submits Step 3 as a SLURM array over `config/mchelper_inputs.tsv`;
6. submits Step 4 after Step 3 finishes;
7. prints a final summary.

Users do not need to edit array sizes. The launcher counts the number of rows in the genome and MCHelper tables automatically.

### Parallelisation strategy

The pipeline parallelises only the computationally intensive steps.

| Step | Execution mode |
|------|----------------|
| Step 1 – RepeatModeler | SLURM array (one genome per task) |
| Step 2 – Known TE filtering | Single job |
| Step 3 – MCHelper | SLURM array (one genome per task) |
| Step 4 – Final filtering | Single job |

The launcher automatically determines the required array sizes from the input tables, so users do not need to edit the SLURM scripts.


## Files

```text
slurm/
├── README.md
├── run_pipeline_slurm.sh
├── Step1_run_repeatmodeler_array.slurm
├── Step2_run_TE_candidates_original_headers.slurm
├── Step3_run_mchelper_array.slurm
└── Step4_run_final_TE_filter_after_MCHelper.slurm
```

## Configure SLURM Resources

Edit the SLURM section in `config.sh`:

```bash
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
```

Leave `SLURM_PARTITION` empty to use the default partition.

Example:

```bash
SLURM_PARTITION="standard"

STEP1_CPUS="16"
STEP1_MEM="64G"
STEP1_TIME="48:00:00"

STEP2_CPUS="16"
STEP2_MEM="16G"
STEP2_TIME="04:00:00"

STEP3_CPUS="16"
STEP3_MEM="32G"
STEP3_TIME="24:00:00"

STEP4_CPUS="16"
STEP4_MEM="32G"
STEP4_TIME="08:00:00"

ARRAY_CONCURRENCY="3"
```

`ARRAY_CONCURRENCY="3"` means that at most three array tasks will run at the same time.

## Logs

The SLURM launcher writes logs to:

```text
logs/slurm/
```

SLURM job output and error files are also written there.

## Resume Behaviour

The SLURM scripts skip steps when their expected outputs already exist:

- Step 1 skips a genome if `consensi.fa.classified` already exists.
- Step 2 skips if `TE_candidate_screen_original_headers/summary.tsv` already exists.
- Step 3 skips a genome if `curated_sequences_NR.fa` already exists.
- Step 4 skips if `final_TE_candidates_after_MCHelper/final_potential_new_TEs.fa` already exists.

If you want to force a step to rerun, remove the corresponding output before launching the pipeline again.

## Cluster Adaptation

These scripts are examples and may need small edits for local HPC policies, especially if your cluster requires account names, QoS names, modules, or specific partitions.

Keep biological parameters in `config.sh`. Do not edit thresholds or commands in the SLURM scripts unless you are adapting them to local scheduling rules.
