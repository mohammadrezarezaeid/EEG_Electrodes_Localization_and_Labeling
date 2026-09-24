# Step 5 — Registration and labeling

Gives every detected electrode its name.

## What it does

Step 4 produced 252 points on the scalp. It does not know which one is Cz and
which one is Fp1 — only that there are electrodes there. This step assigns the
labels, by fitting a **template**: a fully labeled cap from another subject,
whose electrode order is known.

The problem is that the two heads have different shapes and sizes, so the
template does not land on the detections by itself. The script deforms the
template until its electrodes sit on the detections, and each template
electrode then hands its label to the detection it landed on.

### The pancake projection

Fitting is done in 2D, not 3D. Each electrode is converted from Cartesian
coordinates to spherical angles (theta, phi) and then flattened onto a disc —
the "pancake" — the same way a scalp map is drawn flat. This turns a matching
problem on a curved surface into a matching problem in a plane, where a 2D
warp can be fitted directly.

At the end, the registered template is converted back: pancake → spherical →
nearest vertex of the head surface, which returns the electrodes to 3D.

### How the matching decides

Every template electrode is scored against every detection with two features,
multiplied together:

**Feature 1 — where it should be.** A Gaussian centred on each detection. A
template electrode scores high on detections that are simply close to it. 

**Feature 2 — whether the neighbours agree.** An electrode is not an isolated
point but part of a regular grid. This feature takes the template electrode's
neighbours, shifts them onto the candidate detection, and asks whether
detections are also found where those neighbours would fall. A match is only
credible if the whole local pattern lines up, not just the one point. Once some
electrodes are labeled, the feature requires the labeled neighbours to match
*their own* detections rather than any detection, which sharpens the score as
the process goes on.

### Why it iterates

Only confident matches are accepted at each pass: a template electrode is
labeled only when its best detection beats the runner-up by a margin, **and**
that detection's own best template is the same electrode. This mutual test
means a few electrodes are labeled first, in the easy regions.

Those labeled pairs become control points for a piecewise linear warp, which
pulls the whole template closer to the detections. With the template better
placed, more matches become confident on the next pass, which improves the
warp again. 


## Input

| File | Where it comes from |
|---|---|
| `HC023_Detection.mat` | step 4 — the detected coordinates |
| `selected_surface_HC023.mat` | step 4 — the surface used to put the result back in 3D |
| `HC024_electrode_position_SCS.mat` | the **template**: a labeled cap from a different subject |
| `HC023_electrode_position_SCS.mat` | step 2 part B — ground truth, used only for the final evaluation |

The template is another subject's ground truth, so it is a real, correctly
ordered cap. HC023's own ground truth is never used to fit anything; it is read
only at the last step to measure the error.

## Output

Printed to the console:

```
Mean error: 2.83 mm
Std error : 2.27 mm
Localization accuracy     : 97.67 electrodes
```

`EEG_cap_denorm` in the workspace is the labeled cap: `[258 x 3]`, row `i` is
the position assigned to electrode `i` of the cap layout.

## How to run

```matlab
Registration_EX
```

Needs the Image Processing Toolbox (`imgaussfilt`, `imdilate`, `strel`) and
the Statistics Toolbox (`geomean`). `fitgeotform2d` requires MATLAB R2022b or
newer; on older versions use `fitgeotrans` with `'pwl'`.

Set `plot_itr = false` to suppress the two figures per iteration.



## Parameters

| Parameter | Value | Meaning |
|---|---|---|
| `templateNum` | 24 | which subject provides the template cap |
| `dx`, `dy` | 0.01 | pancake grid resolution; the grid is 401 x 401 |
| `std_prior` | 30 | width of the Gaussian of feature 1, in grid cells |
| `std_neighborhood` | 5 | width of the Gaussian of feature 2, in grid cells |
| `neighborhood_size` | 30 | half-width of the box that defines an electrode's neighbours, in grid cells |
| `threshold` | 0.35 | margin the best match must beat the runner-up by |
| `threshold_diff` | 0.01 | amount the threshold drops when the template stops moving |
| `n_iteration` | 15 | number of match-and-warp passes |

This is the **constant-sigma** variant: feature 2 uses one width for every
electrode. The companion script uses a width that grows with the distance to
the neighbour; the two are compared in the article.

## Files in this folder

| File | Role |
|---|---|
| `Registration_EX.m` | the script to run |
| `feature1_calc.m` | the spatial prior |
| `feature2_calc.m` | the neighbourhood consistency score |
| `cartesian_to_spherical.m`, `spherical_to_pancake.m` | 3D to flat disc |
| `pancake_to_spherical.m`, `spherical_to_cartesian.m` | flat disc back to 3D |
| `load_electrodes_file.m` | reads the first variable of a `.mat`, whatever it is named |

## Next

This is the last step. The labeled cap can now be exported to the EEG analysis
software of your choice.
