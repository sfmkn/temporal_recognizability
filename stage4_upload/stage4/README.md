# Stage 4 — Temporal Recognizability of Distribution-Network Fault Classes

## Overview

This directory contains the available source code, frozen configurations, evaluation results, and selected figures for Stage 4 of the COSC 750 Temporal Recognizability research project.

The study investigates how fault-class recognition performance changes as the post-fault observation window increases.

## Experimental setting

- Distribution network: IEEE 33-bus system.
- Fault classes: AG, BG, CG, AB, BC, CA, ABG, BCG, CAG, ABC.
- Dataset: 2,000 balanced fault events.
- Measurement channels: Va, Vb, Vc, Ia, Ib, Ic.
- Sampling frequency: 100 kHz.
- System frequency: 60 Hz.
- Observation windows: 20, spanning T/128 through 3T.
- Independent test set: 300 events.

## Stage 3 and Stage 4

Stage 3 established conventional machine-learning baselines and examined aggregate recognition performance across observation windows.

Stage 4 extends the analysis using a 1D-CNN, model comparisons, independent-test evaluation, and class-specific recognition criteria.

Stage 3 used an aggregate accuracy and macro-F1 threshold of 0.90 with a next-window persistence requirement.

Stage 4 evaluates class-specific F1 against a threshold of 0.95 and examines sustained satisfaction across subsequent evaluated windows.

## Principal Stage 4 finding

The saved independent-test evaluation identifies W08 (T = 16.67 ms at 60 Hz) as the earliest evaluated window at which all ten fault classes satisfy the class-specific F1 >= 0.95 criterion, with the criterion maintained at subsequent evaluated windows.

This result applies to the frozen dataset, model, and experimental protocol. It is not claimed as a universal physical recognition-time limit.

## Repository contents

- `config/`: Frozen CNN architecture and cross-validation assignments.
- `scripts/runCNNOuterFold.m`: CNN outer-fold training and evaluation function.
- `scripts/data_generation/`: Available simulation, configuration, event-generation, and auditing functions.
- `simulation/`: Two relevant Simulink model versions retained for provenance.
- `results/model_comparison/`: Final 20-window model comparison.
- `results/statistical_analysis/`: Statistical comparisons, ablation analyses, and threshold sensitivity.
- `results/heldout_evaluation/`: Independent-test summaries, class-specific F1 scores, and compact CNN evaluation audit.
- `figures/`: Selected research figures.

## Reproducibility and dependencies

The original waveform dataset comprises 40,000 MATLAB files totaling approximately 4.11 GB and is not included in this directory.

The available CNN training function requires the original temporal-window waveform files and currently contains MATLAB Drive-specific paths.

The scripts have not been validated as a standalone end-to-end reproduction workflow from a fresh GitHub checkout.

MATLAB, Simulink, and relevant machine-learning and deep-learning capabilities are required for the corresponding workflows. Exact software dependencies should be verified against the original environment.

## Simulink model provenance

The available batch-generation function selects `IEEE33_TR_TEMPORAL_RECOGNIZABILITY_WORKING_COPY_1`.

The event-saving function records `IEEE33_TR_TEMPORAL_RECOGNIZABILITY_MASTER` as the model version in metadata.

Both model files are retained. Their equivalence and the precise provenance of every frozen event have not been independently established.

## Research scope

The completed Stage 4 analysis concerns temporal multiclass recognition and class-specific recognition thresholds.

The broader investigation of physical operating conditions, time-varying pairwise distinguishability, pairwise recognition performance, and pairwise reliable recognition times is reserved for subsequent research.

## Data integrity

The original experimental outputs and frozen evaluation protocol have not been modified during preparation of this repository package.
