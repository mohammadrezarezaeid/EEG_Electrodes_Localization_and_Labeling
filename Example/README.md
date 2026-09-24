# Automatic and General Localization and Labeling of EEG Electrodes for Simultaneous EEG-fMRI (Example)

This repository contains an end-to-end worked example on one subject, HC023.

The example runs the complete pipeline on a single head, from the
preprocessed MR volume to labeled electrode coordinates. Every step is a short,
self-contained script that can be run on its own, so each stage can be
inspected and compared against the corresponding section of the article.

HC023 was **not** used to train any of the models shipped here. It is the
held-out subject of the reported evaluation, which is why it is the example.

---

## 1. Example data

Everything needed to run the example is in [`data_example/`](data_example).
Two files are the input to the pipeline:

| File | What it is |
|---|---|
| `HC023_with_mni_restore.nii` | The preprocessed T1 volume of subject HC023, after the MNI normalization described in Preprocessing. |
| `HC023_electrode_position.xlsx` | The ground-truth electrode coordinates, marked manually in MRIcron on the same volume. One row per electrode: the 256 cap electrodes first, followed by the reference, ground and dummy electrodes. |

The folder also contains the preprocessing itself:

| File | What it is |
|---|---|
| `preprocessing_fsl.sh` | The FSL commands used to produce `HC023_with_mni_restore.nii` from the raw T1. Included so the preprocessing can be reproduced or applied to a new subject, and so the exact tool versions and parameters are on record. |


---

## 2. Pipeline overview

The pipeline has five stages. Each has its own folder, its own README.

| Stage | Folder | Input | Output |
|---|---|---|---|
| 1. Preprocessing and surface extraction | `01_surface_extraction/` | `HC023_with_mni_restore.nii` | 20 head surfaces |
| 2. Curvature features | `02_features/` | the 20 surfaces | 110 features per vertex |
| 3. Vertex classification | `03_classification/` | the features | per-vertex electrode / non-electrode labels |
| 4. Detection | `04_detection/` | the vertex labels | N x 3 electrode coordinates |
| 5. Registration and labeling | `05_registration/` | the detections + a template | labeled electrodes, one per cap position |

Stages 1 to 3 turn the volume into a per-vertex decision. Stage 4 turns those
vertices into electrode positions. Stage 5 assigns a cap label to each
position. **Detection** and **registration** are separate problems, evaluated
separately in the paper, and they are kept separate here.

Run them in order; each stage writes the file the next one reads.

### What a "head surface" is here

Step 1 does not output an image. It outputs a **triangular mesh**: the scalp
represented as a surface made of flat triangles, the same way 3D models are
stored in graphics. Each mesh is a MATLAB struct with two fields:

| Field | Size | Meaning |
|---|---|---|
| `Vertices` | `n x 3` | the 3D coordinates of the `n` corner points of the mesh |
| `Faces` | `m x 3` | the `m` triangles, each given as the row numbers of its three vertices in `Vertices` |

So `Faces(k,:) = [12 57 58]` means triangle `k` is the triangle whose corners
are `Vertices(12,:)`, `Vertices(57,:)` and `Vertices(58,:)`. Vertices hold the
geometry; faces hold how the vertices are joined.

---

## 3. Steps

### Step 1 — Preprocessing and surface extraction

**Input:** `data_example/HC023_with_mni_restore.nii`
**Output:** [folder] — 20 head surfaces, one per intensity threshold


---

### Step 2 — Curvature features

**Input:** the 20 surfaces
**Output:** `HC023_features_vertices.mat` — 110 features per vertex, per surface

---

### Step 3 — Vertex classification


**Input:** `HC023_features_vertices.mat`, plus the trained models in `models/`
**Output:** `HC023_pred.mat` — one 0/1 label per vertex, per surface


---

### Step 4 — Detection


**Input:** `HC023_pred.mat`, the 20 surfaces, the area prior
**Output:** `HC023_Detection.mat` — N x 3 electrode coordinates


---

### Step 5 — Registration and labeling


**Input:** `HC023_Detection.mat`, the template
**Output:** labeled electrode positions

---

## 4. Expected results

Running the example on HC023 should reproduce:

| Quantity | Value |
|---|---|
| Detection rate | [97.67] % |
| Labeling error | [2.83] +- [2.27] mm |

---

## 5. Requirements

- MATLAB 2023
- Brainstorm (step 1)
- FSL (preprocessing only)
- Python >= 3.8 with PyTorch >= 1.13, NumPy, SciPy (step 3)

