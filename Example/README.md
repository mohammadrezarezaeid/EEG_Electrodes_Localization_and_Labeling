# Automatic and General Localization and Labeling of EEG Electrodes for Simultaneous EEG-fMRI

This repository contains the implementation and supporting codes for the article:

**“Automatic and General Localization and Labeling of EEG Electrodes for Simultaneous EEG-fMRI”**

The project introduces a fully automated framework for EEG electrode localization and labeling using only T1-weighted MRI images, without requiring additional hardware or specialized MRI acquisition sequences.

---

# Repository Structure

```text
├── Preprocessing/
├── Detection/
├── Registration/
├── Manual_Labeling/
└── README.md
```

---

# Pipeline Overview

## 1. Preprocessing
This section contains the preprocessing pipeline for T1-weighted MRI images.

## 2. Detection
This section contains the automated EEG electrode detection pipeline.

## 3. Registration
This section contains the registration and labeling framework used to align detected electrodes with a standard EEG template and assign electrode labels automatically.

## 4. Manual_Labeling
This section contains the manual labeling tools and ground truth preparation methods used for validation and evaluation of the automated framework.

---

# Methods Summary

The proposed framework consists of the following main stages:

1. MRI preprocessing and spatial normalization
2. Head surface extraction
3. Curvature feature extraction from mesh vertices
4. Vertex-wise electrode classification using neural networks
5. Surface clustering and candidate electrode estimation
6. Electrode registration to EEG templates
7. Automatic electrode labeling

---

# Implemented Technologies

- MATLAB
- Python
- PyTorch
- Google Colab
- GPU acceleration
- Mesh processing techniques
- Curvature-based feature extraction
- DBSCAN clustering
- Registration methods for EEG template alignment

---

# Data Availability

The 64-electrode datasets are accessible via OSF:

- https://osf.io/w6bh3/

The 256-electrode dataset is available upon request, subject to a formal data-sharing agreement and approval from the relevant ethics committees.

---

# Citation

If you use this repository or the proposed methodology in your research, please cite the associated article.

```bibtex
@article{Rezaei2026,
  title={Automatic and General Localization and Labeling of EEG Electrodes for Simultaneous EEG-fMRI},
  author={Rezaei, Mohammadreza and others},
  journal={},
  year={2026}
}
```

---

# Contact

For questions, collaborations, or dataset access requests, please open an issue in this repository or contact the authors.
