# Temporal Recognizability of Distribution-Network Fault Classes

## Overview

This project studies how early after fault inception sufficient information becomes available to reliably recognize distribution-network fault classes. Rather than evaluating fault classification only at a single fixed observation window, the same physical fault events are evaluated using progressively longer cumulative post-fault windows.

The study uses an IEEE 33-bus distribution network and ten fault classes:

`AG, BG, CG, AB, BC, CA, ABG, BCG, CAG, ABC`

The principal research quantity is the temporal recognizability time `t_R`.

## Dataset

The frozen dataset contains 2,000 balanced physical fault events.

- Fault locations: buses 4, 10, 18, 25, and 33
- Measurements: Va, Vb, Vc, Ia, Ib, Ic
- Sampling frequency: 100 kHz
- System frequency: 60 Hz
- Fault resistance: 0.01-100 ohm
- Fault inception angle: 0-360 degrees
- Loading level: 0.8-1.2 pu

Each physical event is represented at 20 cumulative post-fault observation windows from T/128 through 3T. Therefore, the temporal dataset contains 40,000 derived observations originating from 2,000 independent physical fault events.

## Feature Representation

The Stage-3 baselines use a frozen 48-dimensional time-domain feature representation. Eight statistical features are extracted from each of the six measured channels.

The eight features are:

1. Mean
2. Standard deviation
3. RMS
4. Maximum absolute value
5. Peak-to-peak value
6. Mean absolute value
7. First-to-last change
8. Maximum absolute first difference

Scenario metadata such as fault resistance, fault location, inception angle, and loading level are not provided to the classifiers.

## Baselines

Three Stage-3 baselines are implemented:

1. RBF-SVM: C = 300, KernelScale = 10
2. Adapted Hojabri-style KNN: k = 5, Manhattan distance, inverse-distance weighting
3. Uniform-random classifier: ten equiprobable classes

## Experimental Protocol

The frozen event-level split contains:

- Training: 1,400 events
- Validation: 300 events
- Locked test: 300 events

For Stage-3 baseline stability estimation, the original training and validation partitions form a 1,700-event development set. Repeated stratified 5-fold cross-validation is performed for five repeats, giving 25 matched evaluations per temporal window.

Feature standardization is fitted only on the training portion of each cross-validation fold and then applied to the corresponding validation portion. The locked 300-event test set is not used by the baseline reproduction script.

Reported metrics are:

- Accuracy
- Macro-F1
- Mean and empirical sample standard deviation over 25 evaluations

## Reproducing the Stage-3 Baselines

Required software:

- MATLAB R2026b
- Statistics and Machine Learning Toolbox 26.2

See `environment.txt` for the recorded execution environment.

From MATLAB, add the scripts directory to the path:

```matlab
addpath('/MATLAB Drive/Temporal_Recognizability_Dataset/scripts')
```

Then reproduce the complete baseline table with one command:

```matlab
reproduce_baselines
```

The script independently retrains all baseline models using the frozen
feature datasets and frozen repeated-CV assignments.

Reproduced results are written to:

```text
Results/Reproduction/STAGE3_BASELINES_REPRODUCED.mat
Results/Reproduction/STAGE3_BASELINES_REPRODUCED.csv
```

## Key Reproduced Result

At the critical T/8 observation window:

| Model | Mean Accuracy | SD |
|---|---:|---:|
| RBF-SVM | 90.40% | 1.29% |
| Adapted Hojabri-style KNN | 50.84% | 2.57% |
| Uniform Random | 9.64% | 1.49% |

The RBF-SVM first satisfies the study-defined temporal recognizability criterion at T/8, with the criterion remaining satisfied at the immediately following T/4 window.

## Temporal Recognizability Criterion

The temporal recognizability time `t_R` is defined in this study as the earliest cumulative post-fault observation window at which mean cross-validated Accuracy and mean Macro-F1 are both at least 0.90, provided that both criteria remain satisfied at the immediately following observation window.

This 0.90 threshold is a study-defined high-reliability criterion and is not claimed as a universal literature threshold.

## Proposed Method

The proposed method is a compact multichannel 1D-CNN operating directly on synchronized three-phase voltage and current waveforms. Its purpose is to investigate whether learned short-time waveform representations can move the recognizability time earlier than the feature-based baselines.

The CNN itself is not claimed as the primary novelty. The contribution is the temporal-recognizability framework that evaluates classification performance as a function of progressively increasing post-fault observation time.

## Repository Structure

```text
Temporal_Recognizability_Dataset/
|-- README.md
|-- environment.txt
|-- Feature_Dataset_V1/
|-- Temporal_Windows/
|-- Manifest/
|-- Results/
|   |-- CrossValidation/
|   |-- SVM/
|   |-- KNN/
|   |-- ClassAnalysis/
|   |-- FinalTest/
|   `-- Reproduction/
|-- Logs/
`-- scripts/
    `-- reproduce_baselines.m
```

## Reproducibility Status

The Stage-3 reproduction script has been executed successfully. RBF-SVM, adapted KNN, and uniform-random results reproduced the previously frozen repeated-CV results across all 20 temporal windows to the reported precision.

## Data Integrity

The raw physical-event dataset, temporal-window dataset, feature representation, cross-validation assignments, baseline configurations, and final test results are treated as frozen experimental artifacts. They should not be modified during reproduction.
