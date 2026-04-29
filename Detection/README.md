# EEG Electrode Detection Pipeline

This repository contains the complete EEG electrode detection pipeline developed for MRI-based electrode localization.

The pipeline extracts scalp surfaces from MRI data, computes geometric surface features, classifies electrode candidate vertices using a neural network, and refines the detections through surface clustering and filtering.

Each stage of the pipeline is organized into a separate folder with its own dedicated README file.

---

# Pipeline Structure

## 1. `Head_Surface_Extraction`

This stage extracts multiple scalp surfaces from preprocessed T1-weighted MRI images.

### Main Steps

- Load preprocessed T1w MRI
- Extract head/scalp surfaces
- Generate multiple surfaces
- Transform all surfaces into SCS (Subject Coordinate System) space

### Output

- Surface meshes for each subject in SCS space

---

## 2. `Ground_Truth_Transformation_MNI_to_SCS`

This stage transforms manually labeled electrode positions from MNI space into the subject-specific SCS coordinate system.

### Main Steps

- Load electrode ground-truth coordinates in MNI space
- Apply transformation matrices
- Convert electrode locations into SCS space

### Output

- Ground-truth electrode coordinates in SCS space

---

## 3. `Surface_Feature_Extraction`

This stage extracts geometric surface features from each mesh vertex.

### Main Steps

- Load scalp surfaces
- Compute curvature-based features
- Extract local geometric information for every vertex
- Generate feature matrices for classification

### Output

- Vertex-wise feature representations for all surfaces

---

## 4. `Surface_Classification`

This stage performs electrode candidate classification using a neural network.

### Main Steps

- Define vertex labels using ground-truth electrode regions
- Train a Multi-Layer Perceptron (MLP) classifier
- Perform vertex-wise electrode classification
- Use PyTorch GPU acceleration for efficient training and inference

### Output

- Predicted electrode candidate vertices

---

## 5. `Surface_Clustering`

This stage refines the predicted electrode vertices and estimates final electrode locations.

### Main Steps

- Remove unrealistic detections using surface-area filtering
- Cluster neighboring electrode candidate vertices
- Merge connected regions
- Estimate final electrode centers
- Compare detections with ground truth
- Prepare final detections for registration

### Output

- Final electrode candidate positions
- Detection performance evaluation
- Electrode positions for registration

---

# Complete Detection Pipeline

```text
T1w MRI
   ↓
Head Surface Extraction
   ↓
Ground Truth Transformation (MNI → SCS)
   ↓
Surface Feature Extraction
   ↓
Surface Classification (MLP)
   ↓
Surface Clustering and Filtering
   ↓
Final Electrode Detection

```

# Requirements

- MATLAB
- PyTorch
- Python
- GPU support 

---

# Notes

- All processing is performed in SCS space.
- Surface classification is performed vertex-wise.
- Multiple scalp surfaces are used to improve robustness.