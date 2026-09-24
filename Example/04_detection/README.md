# Step 4 — Detection

Turns the per-vertex labels of step 3 into a list of electrode coordinates.

## What it does

Step 3 labels vertices. An electrode is not a vertex, though — it is a patch of
a hundred or so neighbouring vertices, and it appears on several of the 20
surfaces at once. This step converts those labelled vertices into one 3D point
per electrode, in five stages:

**1. Group the labelled vertices into patches.** On each surface, the triangles
touching a labelled vertex are collected and split into connected components by
region growing. Each component is one blob of "electrode-looking" surface.

**2. Keep only the electrode-sized ones.** A real electrode covers a
characteristic area. Every patch area is compared against a reference
distribution measured on the training subjects, and patches outside mean ± 2 SD
are discarded. This removes both the speckle left by a few isolated
misclassified vertices and the oversized blobs where the classifier
over-responded. 

**3. One coordinate per patch.** Each surviving patch is reduced to the average
position of its vertices, giving a list of candidate electrode positions for
that surface.

**4. Pool the 20 surfaces.** All candidates from all surfaces go into one set.
The same electrode now appears several times, once per surface that saw it.

**5. Cluster with DBSCAN.** Candidates within 8 mm of each other are merged
into one detection, placed at the mean of the cluster. Candidates that end up
alone are labelled noise by DBSCAN and dropped, which is what removes responses
appearing on a single surface only. Finally, clusters below z = −75 mm are cut,
since that is neck rather than scalp.

The result is one coordinate per detected electrode.


## Input

| File | Where it comes from |
|---|---|
| `HC023_pred.mat` | step 3 — the per-vertex labels |
| `Dataset_surface_Extracted_Hist_match/HC023/result_with_surf*.mat` | step 1 — the 20 surfaces |
| `HC023_electrode_position_SCS.mat` | step 2 part B — ground truth, used only for the evaluation at the end |
| `total_area_training.mat` | in this folder — the patch-area reference, `total_area` is `[nElectrodes x 20]`, one column per surface |

The area reference comes from the **training** subjects, so no information
about HC023 enters the gate.

Surface `c` in `HC023_pred.mat` must be the same mesh as the `c`-th file of
`dir('result_with_surf*.mat')`. The script checks that the label vector and the
mesh have the same length and stops if they do not.

## Output

| File | Content |
|---|---|
| `HC023_Detection.mat` | `detections` — `[N x 3]`, the detected electrode coordinates in SCS millimetres. This is the output of the detection stage |
| `selected_surface_HC023.mat` | `Vertices`, `Faces` and `selectedSurfaceIdx` — the surface the detections were projected onto |

The second file exists because the detections are means of points taken from
several meshes, so they do not lie exactly on any one of them. The script picks
the surface whose vertices are collectively closest to the detections, snaps
both the detections and the ground truth onto it, and compares them there.
Step 5 needs that same surface to map its labelled electrodes back into 3D.

## How to run

```matlab
DBSCAN_Clustering_for_detections
```

Needs the Statistics and Machine Learning Toolbox for `dbscan` and `knnsearch`.
Set `params.drawFigure = false` to skip the 3D scatter plot.


## Expected output

For HC023 with the shipped predictions:

| Quantity | Value |
|---|---|
| Detections | 252 |
| True positives | 243 |
| False positives | 9 |
| **Detection rate (recall)** | **93.80 %** |
| Precision | 96.43 % |
| Localization error | 2.04 ± 1.57 mm |
| Surface used for matching | 10 |


## Parameters

| Parameter | Value | Meaning |
|---|---|---|
| `dbscanEpsilon` | 8 mm | merge radius; kept below the smallest inter-electrode spacing of the cap so two neighbours cannot merge into one detection |
| `dbscanMinPts` | 2 | minimum cluster size. Note this counts candidate points, not surfaces |
| `falsePositiveThresh` | 10 mm | matching tolerance, the same for every method compared in the article |
| `zThreshold` | −75 mm | neck cut, applied after clustering |
| `mainElectrodeCount` | 258 | rows beyond this in the ground truth are dummy electrodes, excluded from the scored set |

## Next

Step 5 takes `HC023_Detection.mat` and `selected_surface_HC023.mat`, registers
a template cap onto the detections, and assigns each detection its electrode
label.
