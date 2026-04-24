# MRI Preprocessing (FSL)

This module performs preprocessing of MRI data prior to EEG electrode detection and registration.

---

## Overview

The preprocessing pipeline prepares MRI scans by:

1. Reorienting the image to a consistent coordinate system  
2. Registering the MRI to MNI space  
3. Correcting intensity inhomogeneity (bias field correction)  
4. Cropping the volume (optional)

These steps ensure that all subjects are aligned in a common space and suitable for subsequent electrode detection.

---

## Requirements

- FSL (tested with version 6.0.0)
- Linux or HPC environment with module support (or local FSL installation)

---

## Reference Template

The preprocessing pipeline requires an MNI template for registration.

We use:

- `mb_mni_avg218T1.nii.gz`

This file serves as the reference image for affine registration using FSL (`flirt`).

Make sure this file is available in your working directory or update the path in the script accordingly.

---

## Pipeline Steps

### 1. Reorientation

```bash
fslswapdim input.nii RL PA IS output.nii
```

Ensures consistent orientation and avoids flipping issues during registration.

---

### 2. Affine Registration to MNI Space

```bash
flirt -in input.nii -ref mb_mni_avg218T1.nii.gz -dof 12
```

- Uses affine transformation (12 degrees of freedom)  
- Aligns subject MRI to the MNI template  

---

### 3. Bias Field Correction

```bash
fast --nopve -B -O 0 input.nii.gz
```

- Corrects intensity inhomogeneity  
- Improves downstream processing  

---

### 4. Cropping (Optional)

```bash
fslroi input.nii.gz output.nii.gz 0 -1 0 -1 110 -1
```

- Extracts a subvolume to reduce computational cost  
- Cropping parameters may vary depending on dataset  

---

## How to Run

```bash
cd preprocessing
bash preprocess_mri_fsl.sh
```

---

## Input

- Raw MRI scan (`.nii`)
- MNI template: `mb_mni_avg218T1.nii.gz`

---

## Output

- Reoriented MRI  
- MNI-aligned MRI  
- Bias-corrected MRI (`*_restore.nii.gz`)  
- Cropped MRI (optional)  

---

## Notes

- Only affine registration (FLIRT) is used (no nonlinear registration)  
- File names and paths can be modified inside the script  
- This preprocessing step is required before electrode detection  
