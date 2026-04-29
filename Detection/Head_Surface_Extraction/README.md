# EEG Electrode Detection – Head Surface Extraction

This module performs **head surface extraction**, which is the first step of the EEG electrode detection pipeline.

The goal is to extract 3D head surfaces from MRI data that will later be used for electrode detection.

---

## Overview

This stage processes MRI data using Brainstorm and MATLAB to generate surface meshes of the head.

The pipeline consists of:

1. MRI normalization in Brainstorm and transformation to SCS coordinate system  
2. Histogram-based threshold estimation  
3. Global thresholding segmentation  
4. Surface extraction (isosurface)

The output is a set of 3D surfaces (vertices and faces) representing the head, segmented at different intensity thresholds.

---

## Requirements

- MATLAB  
- Brainstorm toolbox  

Start Brainstorm:

```matlab
brainstorm
```

---

## Pipeline Steps

### 1. Brainstorm Initialization and Normalization

Create a simple protocol in Brainstorm and load the MRI dataset.

Even if the MRI data is already normalized, Brainstorm requires running its normalization step to properly register and process the data within its framework.

This step is performed using:

- Function: `mni_normalization_brainstorm`  
- Script: `Normalize_Dataset.m`  

---

### 2. Histogram-Based Threshold Estimation

To identify meaningful intensity ranges (air → scalp, including regions corresponding to electrodes → white matter), histogram analysis is performed on the normalized MRI.

Brainstorm automatically computes intensity distributions that enable estimation of:

- Air threshold  
- White matter threshold  

This step uses:

- `findhistPeriod`  
- `Total_thresholding`  

These functions determine the valid intensity interval for segmentation.

---

### 3. Head Surface Extraction

Head surfaces are extracted using global thresholding followed by isosurface generation.

Steps:

1. Apply global thresholding segmentation  
2. Generate volumetric masks  
3. Extract 3D surfaces using isosurface representation  

**Coordinate System Note**

Brainstorm extracts data in the **SCS (Subject Coordinate System)**. It also provides a transformation matrix to map between SCS and MNI coordinates.

In this work:
- All processing is performed in **SCS space**  
- Ground truth electrode coordinates are also transformed to SCS for consistency  

For additional details, refer to the Brainstorm documentation (https://neuroimage.usc.edu/brainstorm/CoordinateSystems).

---

This produces surface meshes consisting of:

- Vertices (3D coordinates)  
- Faces (mesh connectivity)  

This step is implemented using:

- Function: `headsurfext`  
- Script: `Surface_Ext_Dataset_Hist_match.m`  

---

## Output

- 3D head surface meshes  
  - Vertices  
  - Faces  
- Surfaces generated at different threshold levels  

These surfaces are used in the subsequent stage of electrode detection.

---

## Notes

- Brainstorm can perform these steps via its GUI; however, this implementation uses scripted functions for reproducibility and efficient processing of large datasets  
- Histogram thresholds are derived from Brainstorm-processed data  
- Surface extraction relies on isosurface representation of volumetric MRI data  