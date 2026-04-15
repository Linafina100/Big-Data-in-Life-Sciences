# Big Data in Life Sciences - Assignment 1

This repository contains the automated SLURM pipeline script (`fly_pipeline.sh`) used to process next-generation sequencing (NGS) data from *Drosophila melanogaster* (fruit fly).

## Pipeline Overview
The script processes raw `.fq.gz` sequencing reads and outputs plain-text `.vcf` files containing genomic variants. It automates the following tools:
* **Alignment:** Bowtie2 (v2.5.4)
* **Sorting & Indexing:** SAMtools (v1.22.1)
* **Variant Calling:** BCFtools (v1.22.1)

## Usage
To execute the pipeline on a SLURM cluster, submit the batch job:
```bash
sbatch fly_pipeline.sh
