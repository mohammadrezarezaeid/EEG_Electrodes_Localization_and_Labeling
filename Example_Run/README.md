# EEG electrode detection and labeling from MR images: example

This example runs the full pipeline on one subject (HC023). It starts from a T1-weighted MRI and ends with the labeled EEG electrode coordinates.

There are four scripts to run in order:

1. `step1_feature_extraction.m`
2. `step2_classification.py`
3. `step3_detection.m`
4. `step4_registration.m`

You don't need to move any files between steps. Each script finds its inputs relative to its own folder and creates the `results/` folders itself.

---

## Requirements

### MATLAB (tested with R2023)

You need these toolboxes and add-ons:

- **Image Processing Toolbox**
- **Statistics and Machine Learning Toolbox**
- **[Brainstorm](https://neuroimage.usc.edu/brainstorm/Installation)**, on the MATLAB path, with a database folder configured. If you have never used Brainstorm, run `brainstorm` once interactively to set this up.
- **SPM12 plugin of Brainstorm**, used for the MNI normalization. Brainstorm offers to install it the first time it is needed.
- **[GetCurvatures.m](https://www.mathworks.com/matlabcentral/fileexchange/47134-curvature-estimationl-on-triangle-mesh)** by Itzik Ben Shabat. In MATLAB, go to **Home > Add-Ons**, search for *"Curvature Estimation On Triangle Mesh"*, and install it.

### Python 3.9 or newer

You need `numpy`, `scipy` and [PyTorch](https://pytorch.org/get-started/locally/). Step 2 runs on a CPU, on a local NVIDIA GPU, or in Google Colab. The [Step 2 setup](#step-2-setup-python-cpu-or-gpu) section below shows how to install these.

---

## Instructions (example subject HC023)

### Step 1: run `step1_feature_extraction.m` in MATLAB

**Input** (provided in `data/`):
- `HC023_with_mni_restore.nii.gz`
- `HC023_electrode_position.xlsx`

**What it does:**
1. Imports the MRI into Brainstorm and MNI-normalizes it.
2. Extracts 20 head surfaces, one per intensity threshold.
3. Converts the ground-truth electrode positions from MNI to SCS.
4. Labels the ground truth on every surface.
5. Computes 110 curvature features for every vertex.

**Output:** written to `results/step1/`.


### Step 2: run `step2_classification.py` in Python

**Input:**
- the features and labels from Step 1
- the trained models weights in `Trained_models/` (provided)

**What it does:** applies one trained MLP per surface and labels every vertex as electrode or not.

**How to run it on your computer:**
```
python step2_classification.py
```

**Output:** `results/step2/HC023_pred.mat`

See [Step 2 setup](#step-2-setup-python-cpu-or-gpu) to install Python, use a GPU, or run it in Google Colab.

### Step 3: run `step3_detection.m` in MATLAB

**Input:**
- the predictions from Step 2
- the surfaces and ground truth from Step 1

**What it does:**
1. Groups the predicted vertices into patches.
2. Keeps only the electrode-sized patches.
3. Pools the patch centres over the 20 surfaces and merges them with DBSCAN.
4. Reports the detection rate and false positives against the ground truth.

**Output:**
- `results/step3/HC023_Detection.mat`, the detected electrodes
- `results/step3/selected_surface_HC023.mat`, selected surfaces for step4

### Step 4: run `step4_registration.m` in MATLAB

**Input:**
- the detections and selected surface from Step 3
- the ground truth from Step 1
- the template cap `data/HC024_electrode_position_SCS.mat` (provided)

**What it does:** iteratively labels the detections and registers the template cap onto them with a piecewise-linear registration. It then reports the error against the ground truth.

**Output:** `results/step4/HC023_registered_electrodes.mat`. This file holds the **final labeled electrode coordinates**.

**Template subjects.** This example registers onto a **single** template subject, HC024. The `Extra_Template/` folder holds the ground-truth caps of 14 more subjects, all in SCS with 256 electrodes, named `HCxxx_electrode_position_SCS.mat`. Any of them can serve as the template.

### Tips for the MATLAB scripts

- Each MATLAB script runs end to end with **Run (F5)**.
- You can also run one section at a time with **Ctrl+Enter**.
- All parameters are in **Section 0** of each script.

---

## Running a new subject (example: HC025)

### 1. Add the subject's files to `data/`

Use exactly these names, with the subject ID in place of `HC025`:

```
data/HC025_with_mni_restore.nii.gz     T1-weighted MRI (NIfTI)
data/HC025_electrode_position.xlsx     ground-truth electrode positions (see the requirements below)
```

### 2. Change the subject in each script

The subject is set in one line per script. Nothing else needs to change.

| Script | Where | Change |
|---|---|---|
| `step1_feature_extraction.m` | Section 0 | `cfg.subjectNum = 25;` |
| `step2_classification.py` | command line | `python step2_classification.py --subject HC025` |
| `step3_detection.m` | Section 0 | `cfg.subjectNum = 25;` |
| `step4_registration.m` | Section 0 | `cfg.subjectNum = 25;` and choose `cfg.templateNum` (see **Template subjects.**) |

### 3. Run Steps 1 to 4 in order, as above

Every file name follows the subject ID automatically. For example, Step 3 writes `results/step3/HC025_Detection.mat` and Step 4 reads it. Results of different subjects are kept side by side in `results/` and never overwrite each other.

---

## Step 2 setup 

### Google Colab (free GPU)

1. Upload this folder to Google Drive.
2. Select **Runtime > Change runtime type > GPU**.
3. Run in a cell:
   ```python
   from google.colab import drive
   drive.mount('/content/drive')
   !python "/content/drive/MyDrive/<this folder>/step2_classification.py"
   ```

