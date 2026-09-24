# Step 1 — Head-surface extraction

Turns the MR volume into the 20 head surfaces that the rest of the pipeline
works on.

## What this step does

It works in two parts:

1. **Import and MNI normalization.** The volume is imported into Brainstorm
   and affinely normalized to MNI space (SPM's `maff8`). This also sets the
   fiducial points (nasion, left and right preauricular), which define the
   SCS coordinate frame. Every coordinate produced later in the pipeline —
   detections, ground truth, labeled electrodes — lives in that frame, so
   this step is what makes them comparable.

2. **Surface extraction at 20 thresholds.** Voxels brighter than a chosen
   intensity are marked as "head". That binary mask is cleaned, its holes are
   filled, and its outer boundary is triangulated into a closed surface. This
   is repeated for 20 different thresholds.


## Input

| File | Where it comes from |
|---|---|
| `HC023_with_mni_restore.nii` | [`../data_example/`](../data_example) |
| `bgleveltotal.mat` | in this folder. Variable `bgleveltotal` = 75.4, the air/background intensity. Lowest threshold of the sweep. |
| `whiteLeveltotal.mat` | in this folder. Variable `whiteLeveltotal` = 841.6, the white-matter intensity. Highest threshold of the sweep. |

Copy the `.nii` from `data_example/` into this folder, or edit `mriFilePath`
at the top of the script to point at it.

The two threshold levels were derived once from the **training** subjects, not
from HC023. Because the volumes are histogram matched beforehand, the same two intensities mean the same tissue in every subject, so the sweep covers the same anatomical range everywhere.

## Output

```
Dataset_surface_Extracted_Hist_match/
  HC023/
    result_with_surf075.mat      <- one file per threshold, 20 in total
    result_with_surf116.mat
    ...
    result_with_surf842.mat
```

Each file holds one variable, `sHead`, with two fields:

| Field | Size | Meaning |
|---|---|---|
| `Vertices` | `n x 3` | coordinates of the mesh points, in **metres**, SCS |
| `Faces` | `m x 3` | triangles, each listing the row numbers of its three vertices |

Later steps convert the vertices to millimetres on load (`Vertices * 1000`).

## How to run

```matlab
Example_Surface_Extraction
```

Brainstorm must be on the MATLAB path. If you have never used it, run
`brainstorm` once interactively first so its database folder gets configured.
The script then creates its own protocol, `SurfaceExtractionExample`, so it
never touches your own Brainstorm data.

## Files in this folder

| File | Role |
|---|---|
| `Example_Surface_Extraction.m` | the script to run; sets the parameters and loops over the 20 thresholds |
| `mni_normalization_brainstorm_EX.m` | imports the NIfTI into Brainstorm and runs the MNI normalization |
| `headsurfext_EX.m` | builds one surface at one threshold. Adapted from Brainstorm's `tess_isohead.m`, with the threshold exposed as an input so it can be swept |
| `bgleveltotal.mat`, `whiteLeveltotal.mat` | the two ends of the threshold sweep |

## Parameters

Set at the top of `Example_Surface_Extraction.m`:

| Parameter | Value | Meaning |
|---|---|---|
| `hist_reolution` | 20 | number of thresholds in the sweep |
| `nVertices` | 500000 | upper limit on mesh size. |
| `erodeFactor` | 0 | radius of the morphological opening that removes small components; 0 turns it off |
| `fillFactor` | 2 | strength of the hole filling applied to the surface |

## Next

Step 2 computes the curvature features of every vertex of every surface.