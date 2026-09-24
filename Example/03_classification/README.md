# Step 3 — Vertex classification

Decides, for every vertex of every surface, whether it lies on an electrode.

## What it does

Step 2 described each vertex with 110 numbers. This step feeds those numbers to
a small neural network that answers one question per vertex: **electrode, or
not?**

There are **20 models**, `mlp_cell01.pt` to `mlp_cell20.pt`, one per surface.

Each model file holds its own weights, its own feature normalization and its
own decision threshold, so nothing else is needed to apply it. None of them
were trained on HC023.

## Input

| File | Where it comes from |
|---|---|
| `HC023_features_vertices.mat` | step 2, part A |
| `HC023_mesh_gt.mat` | step 2, part B — required, see below |
| `mlp_cell01.pt` ... `mlp_cell20.pt` | [`../Trained_models/`](../Trained_models), about 47 MB in total |

**Step 2 part B is required for this step.** The script loads the ground-truth
labels to score its own predictions, so run `GT2SCS.m` and
`Ground_truth_surface_labeling.m` before coming here. The predictions
themselves do not depend on the ground truth — it is used only to compute the
accuracy, recall, precision and false-positive rate that the script prints.

## Output

```
Testing_Results/
  HC023_pred.mat
```

| Variable | Content |
|---|---|
| `predicted` | `{20 x 1}` cell array; element `c` is one 0/1 label per vertex of surface `c` |
| `predicted_prob` | the same, as probabilities rather than decisions |
| `predicted_idx` | the indices of the positive vertices, 1-based, ready for MATLAB |
| `metrics` | one row per surface: surface, accuracy, recall, precision, FPR, TP, FP, FN, TN |

`predicted` is what step 4 reads. The rest is for inspection.

## How to run

This step runs in **Google Colab**, in `Mesh_segmentation_Pytorch_Test.ipynb`.
Colab gives a free GPU and a working PyTorch install, so nothing has to be set
up locally.

1. Upload the repository folder, or at least `models/` and the two `.mat` files
   above, to your Google Drive.
2. Open the notebook in Colab.
3. Run the first cells. The third one mounts your Drive and will ask you to
   authorise access to your own account.
4. **Edit the CONFIG cell.** The paths are hard-coded to the author's Drive:

   ```python
   model_dir   = '/content/drive/MyDrive/Mesh_segmentation_new/Trained_models'
   test_dir    = '/content/drive/MyDrive/Mesh_segmentation_new/Testing_dataset'
   results_dir = '/content/drive/MyDrive/Mesh_segmentation_new/Testing_Results'
   subject     = 'HC023'
   ```

   Change the three folders to wherever you put the files in your own Drive.
   `model_dir` must contain the 20 `.pt` files; `test_dir` must contain
   `HC023_features_vertices.mat` and `HC023_mesh_gt.mat`; `results_dir` is
   created if it does not exist.
5. Run the remaining cells in order.

The same code is also in `mesh_segmentation_pytorch_test.py`, exported from the
notebook. It carries the same hard-coded paths and the same Drive mount, so to
run it outside Colab you must edit the paths and delete these two lines:

```python
from google.colab import drive
drive.mount('/content/drive')
```

Requires Python 3.8 or later with PyTorch, NumPy and SciPy. A GPU makes it
faster but is not needed; the models are small.

**Runtime:** under a minute for all 20 surfaces.

## Expected output

| Surface | Accuracy | Recall | Precision | FPR |
|---|---|---|---|---|
| 1 | 84.42 % | 41.94 % | 59.67 % | 6.24 % |
| 5 | 86.90 % | 72.50 % | 76.35 % | 7.98 % |
| 7 | 89.35 % | 73.92 % | 81.16 % | 5.61 % |
| 13 | 90.11 % | 70.13 % | 81.36 % | 4.41 % |
| 20 | 86.95 % | 58.04 % | 74.79 % | 5.27 % |
| **mean of all 20** | **87.97 %** | **65.62 %** | **77.09 %** | **5.66 %** |

Recall is lowest on the first and last surfaces and peaks in the middle of the
sweep, which is the pattern the multi-surface design exploits: no single
surface finds every electrode, and different surfaces miss different ones.


## Training your own models

The models here were trained on 14 subjects with this feature set. To train on
your own data instead, see [`../Surface_Classification/`](../Surface_Classification). Models trained on
different surfaces or a different feature set are not interchangeable with
these.

## Next

Step 4 groups the positive vertices into patches, filters them by area, and
turns each into one electrode coordinate.
