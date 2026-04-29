# Surface Classification Pipeline

This repository contains the pipeline for **vertex-wise classification of EEG electrode regions** on MRI-derived head meshes.

---

## Components

### 1. `Ground_truth_surface_labeling` (MATLAB)

This module is responsible for:
- Labeling mesh vertices based on ground truth electrode positions  
- Generating binary labels (electrode vs non-electrode)  
- Preparing structured datasets for classification  

All preprocessing and ground truth construction are performed in **MATLAB**.

---

### 2. `Surface_Classification_NN_pytorch` (PyTorch)

This module implements the **classification stage** using a neural network:
- Multi-Layer Perceptron (MLP) for vertex-wise classification  
- Trained on extracted mesh features  

The implementation uses **PyTorch** and leverages **GPU acceleration** to significantly speed up training and inference.

---

### 3. `Surface_Classification_NN_pytorch_colab`

This is the **Jupyter/Google Colab version** of the PyTorch pipeline:
- Same functionality as the PyTorch implementation  
- Designed for easy execution in **Google Colab**  
- Built-in support for GPU runtime  
- Direct integration with Google Drive for dataset access  

---

## Workflow Overview

1. **MATLAB preprocessing**
   - Generate vertex-wise ground truth labels  
   - Export features and labels as `.mat` files  

2. **PyTorch classification**
   - Load feature matrices and labels  
   - Train MLP model  
   - Evaluate performance (accuracy, recall)  
   - Save predicted labels  

---

## Notes

- The pipeline is designed for **64-electrode EEG configurations**  
- Data is stored in `.mat` format for seamless MATLAB ↔ Python compatibility  
- GPU acceleration significantly reduces computation time for large mesh datasets  

---
