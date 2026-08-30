# Big Data in Life Sciences

## Assignment 1
Contains the automated SLURM pipeline script (`fly_pipeline.sh`) used to process next-generation sequencing (NGS) data from *Drosophila melanogaster* (fruit fly).

### Pipeline Overview
The script processes raw `.fq.gz` sequencing reads and outputs plain-text `.vcf` files containing genomic variants. It automates the following tools:
* **Alignment:** Bowtie2 (v2.5.4)
* **Sorting & Indexing:** SAMtools (v1.22.1)
* **Variant Calling:** BCFtools (v1.22.1)

### Usage
To execute the pipeline on a SLURM cluster, submit the batch job:
```bash
sbatch fly_pipeline.sh
```

## Assignment 2
Contains automated Nextflow pipelines for mass trace detection in metabolomics data.

### Pipeline Overview
This assignment implements two separate analytical workflows for processing `.mzML` files:
* **OpenMS Pipeline:** Identifies mass traces using `FeatureFinderMetabo`, aligns features with `MapAlignerPoseClustering`, and links/exports results using `FeatureLinkerUnlabeledQT` and `TextExporter`.
* **XCMS Pipeline:** Processes raw data using `findPeaks.r`, corrects retention time drift using the `obiwarp` method, and groups linked peaks.

## Assignment 3
This notebook (`14_LinaMueller_EllaLindgren.ipynb`) documents the iterative development of a Convolutional Neural Network (CNN) built with TensorFlow and Keras. The objective was to reach a balanced accuracy of at least 82% to accurately identify tumor samples.

### Data
96x96 grayscale cell images collected from Södersjukhuset in Stockholm.

### Architecture
4-layer CNN featuring Batch Normalization and MaxPooling.

### Optimization
Implemented data augmentation (random flips and rotations) and learning rate tuning (Adam optimizer set to 0.0001) to improve generalization and stabilize validation metrics.

### Results
The final model (Model 8) achieved a balanced accuracy of 0.8231 on the validation set and 0.8220 on the test set.
