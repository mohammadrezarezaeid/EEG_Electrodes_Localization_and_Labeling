# EEG Electrode Detection – Feature Extraction

This module extracts **curvature-based features** from head surface meshes to be used as input for the electrode classification model.

---

## Overview

After extracting head surfaces from MRI data, geometric features are computed at each vertex of the mesh.

These features capture local surface shape characteristics that help distinguish electrode regions from the surrounding scalp.

The pipeline includes:

1. Principal curvature estimation  
2. Derived curvature features  
3. Multi-scale neighborhood feature extraction  

---

## Requirements

- MATLAB  
- Curvature estimation toolbox:

Download from MATLAB File Exchange:  
https://www.mathworks.com/matlabcentral/fileexchange/47134-curvature-estimationl-on-triangle-mesh

Make sure the function `GetCurvatures` is added to your MATLAB path.

---

## Curvature Estimation

We use the **Rusinkiewicz curvature estimation algorithm** to compute principal curvatures at each vertex of the mesh.

Let:

- \( k_1 \), \( k_2 \): principal curvatures  

---

## Local (Per-Vertex) Features

For each vertex, the following features are computed:

- \( k_1 \), \( |k_1| \)  
- \( k_2 \), \( |k_2| \)  
- \( k_1 k_2 \) (Gaussian curvature)  
- \( |k_1 k_2| \)  
- \( \frac{k_1 + k_2}{2} \) (Mean curvature)  
- \( \left| \frac{k_1 + k_2}{2} \right| \)  
- Shape Index:  
  \[
  \frac{2}{\pi} \tan^{-1}\left(\frac{k_1 + k_2}{k_1 - k_2}\right)
  \]
- Curvedness:  
  \[
  \sqrt{\frac{k_1^2 + k_2^2}{2}}
  \]

These features form a **10-dimensional descriptor per vertex**, as suggested in prior studies.

---

## Neighborhood Features (Multi-Scale)

To capture local geometric context, features are aggregated over neighborhoods of varying radii:

```
[6, 8, 10, 12, 15] mm
```

For each vertex and each radius:

### Neighbor Selection

- All vertices within a given radius are selected  
- If fewer than 5 neighbors are found, the 5 nearest vertices are used  

---

## Output

For each subject:

- `features_vertices`  
  - Cell array containing feature matrices for each extracted surface  

Each row corresponds to a vertex, and columns represent extracted features.

---

## Input

- Surface meshes from the head surface extraction stage  
  - Vertices  
  - Faces  

---

## Notes

- Vertex coordinates are scaled to millimeters before feature computation  
- Multi-scale neighborhoods improve robustness to electrode size variability  
- SVD-based features capture local structural patterns beyond simple statistics  
- Feature dimensionality increases significantly due to multi-scale aggregation  

---

## References

- Rusinkiewicz, S. “Estimating Curvatures and Their Derivatives on Triangle Meshes.” Proceedings. 2nd International Symposium on 3D Data Processing, Visualization and Transmission, 2004. 3DPVT 2004., IEEE, doi:10.1109/tdpvt.2004.1335277.

- Shabat, Yizhak Ben, and Anath Fischer. “Design of Porous Micro-Structures Using Curvature Analysis for Additive-Manufacturing.” Procedia CIRP, vol. 36, Elsevier BV, 2015, pp. 279–84, doi:10.1016/j.procir.2015.01.057.

