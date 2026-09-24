# Step 2 — Curvature features and ground-truth labels

Describes the shape of the surface around every vertex, so that a classifier
can tell "this looks like an electrode" from "this looks like plain scalp".

This folder has two parts:

- **the feature extraction**, which every run needs;
- **the ground-truth mesh labeling**, which is optional and only needed if you
  want to measure how well the classifiers do in step 3.

---

## Part A — Feature extraction

### What it does

An electrode sits on the scalp as a small bump, so the surface around it curves
differently from the smooth skin next to it. This step measures that curvature
at every vertex.

For each vertex it computes the two **principal curvatures**, k1 and k2, which
say how sharply the surface bends in its most and least curved directions.
From those two numbers it derives eight more descriptors, giving 10 per vertex:

| Feature | What it tells you |
|---|---|
| k1, k2 | how sharply the surface bends, in each of the two principal directions |
| \|k1\|, \|k2\| | the same without the sign, i.e. how curved regardless of direction |
| K = k1·k2 (Gaussian) | the local type: positive on a dome or a pit, negative on a saddle, zero on a flat or cylindrical patch |
| H = (k1+k2)/2 (mean) | bump or dent, given by the sign |
| \|K\|, \|H\| | their magnitudes |
| Shape index | *which* shape it is, on a scale from -1 (cup) to +1 (cap), independent of how strongly curved it is. An electrode should sit near one end |
| Curvedness | *how strongly* curved it is, independent of which shape. The magnitude the shape index deliberately throws away |

One vertex on its own is noisy, and an electrode is much bigger than one
vertex, so the same 10 features are also summarised over neighbourhoods of
five sizes — 6, 8, 10, 12 and 15 mm — by their **mean** and **standard
deviation**. The mean smooths out the noise of the curvature fit; the standard
deviation says how variable the shape is nearby, which is high at the rim of an
electrode and low on flat scalp. The largest radius is about twice the physical
electrode, so the vector describes the electrode and the scalp it sits on at
the same time.

That gives 10 + 5 × 20 = **110 features per vertex**.

### Input

| File | Where it comes from |
|---|---|
| `Dataset_surface_Extracted_Hist_match/HC023/result_with_surf*.mat` | step 1 — the 20 head surfaces |

Nothing else. The features are computed from the geometry alone, so the ground
truth is not involved at any point here.

### Output

```
SavedFeatures_Subject/
  HC023_features_vertices.mat
```

One variable, `features_vertices`, a `{20 x 1}` cell array.
`features_vertices{i}` is `[nVertices x 110]` for surface `i`, with the same
vertex order as that surface's `Vertices`:

### How to run

```matlab
Feature_extraction_test
```

`GetCurvatures.m` must be on the MATLAB path. It is part of the
"Curvature Estimation on Triangle Mesh" toolbox by Itzik Ben Shabat, available
through the MATLAB Add-On Explorer.


### Parameters

| Parameter | Value | Meaning |
|---|---|---|
| `electrodesize` | `[6 8 10 12 15]` | neighbourhood radii in mm |
| `number_of_thresholds` | 20 | number of surfaces from step 1 |

---

## Part B — Ground-truth mesh labeling

### Why you might want it

Step 2 produces features; step 3 turns them into a per-vertex decision. To
*measure* how good that decision is, each vertex also needs a true answer:
was it really on an electrode? That is what this part produces.

### Why it takes two scripts

The manual electrode positions and the surfaces are not in the same coordinate
frame, and the positions are not mesh vertices. So:

**B1. `GT2SCS.m` — put the positions in the same frame as the surfaces.**
The electrode coordinates were marked on the MR volume. The surfaces from step
1 live in SCS, the frame defined by the nasion and preauricular fiducials. This
script applies the transformation stored in the normalized MRI structure of
step 1 and writes the positions out in SCS millimetres. It also saves the
transformation itself, so the mapping can be reused or inverted later without
recomputing it.

**B2. `Ground_truth_surface_labeling.m` — turn positions into vertex labels.**
An electrode position is a single point floating in space; it does not coincide
with any vertex, and an electrode covers many vertices rather than one. So for
each surface the script snaps every electrode to the nearest vertex of *that*
surface, then marks every vertex within 6 mm of it as electrode. The snapping
is redone per surface because each threshold gives a different mesh, so the
nearest vertex differs from one surface to the next.

### Input

| File | Where it comes from |
|---|---|
| `HC023_electrode_position.xlsx` | [`../data_example/`](../data_example) — the manually marked positions |
| `Dataset_surface_Extracted_Hist_match.mat` | step 1 — the normalized Brainstorm MRI structure, which carries the fiducials and therefore the transformation |
| `Dataset_surface_Extracted_Hist_match/HC023/result_with_surf*.mat` | step 1 — the 20 surfaces |

### Output

```
HC023_electrode_position_SCS/
  HC023_electrode_position_SCS.mat   posSCS    : electrode positions in SCS mm
  Transformation2SCS_HC023.mat       transform : the transformation used
Mesh_gt_label/
  HC023_mesh_gt.mat                  Label_vertices : {20 x 1} cell array
```

`Label_vertices{i}` is a column of the vertex indices that belong to an
electrode on surface `i`, stacked over all electrodes. Everything not listed
is a non-electrode vertex. This pairs with `features_vertices{i}` — same
surface, same vertex numbering.

`HC023_electrode_position_SCS.mat` is also what the evaluation in steps 4 and 5
loads.
### How to run

```matlab
GT2SCS                        % B1: positions into SCS
Ground_truth_surface_labeling % B2: positions into per-vertex labels
```

`Transfom2SCS.m` must be in the folder; `GT2SCS.m` calls it.

### Parameter

| Parameter | Value | Meaning |
|---|---|---|
| `current_electrodesize` | 6 mm | radius of the labeled patch around each electrode. It should match the physical size of the electrode on the scalp, and it is the same as the smallest feature radius in part A |

---

## Files in this folder

| File | Role |
|---|---|
| `Feature_extraction_test.m` | part A: the script to run |
| `GT2SCS.m` | part B1: electrode positions into SCS |
| `Transfom2SCS.m` | helper called by `GT2SCS.m` |
| `Ground_truth_surface_labeling.m` | part B2: positions into per-vertex labels |

## Next

Step 3 loads `HC023_features_vertices.mat`, applies the trained classifiers,
and writes one electrode / non-electrode label per vertex. It also reports how that compares with `HC023_mesh_gt.mat`.
