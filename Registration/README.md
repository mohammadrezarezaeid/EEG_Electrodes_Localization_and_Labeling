# Registration Module

This module aligns detected EEG electrodes with a template using
piecewise linear registration in a 2D "pancake" projection.


## Methods

### 1. Distance-Based Standard Deviation
- Adaptive neighborhood modeling
- Standard deviation varies based on electrodes' neighbours distance from their neighborhood

### 2. Constant Standard Deviation
- Fixed neighborhood based on mean of electrodes' neighbours distance from their neighborhood

### Example Data (included)
A small example dataset is provided in `data_example/` to demonstrate the pipeline.

## Pipeline

1. Cartesian → Spherical → Pancake
2. Feature computation:
   - Feature 1: Spatial prior
   - Feature 2: Neighborhood consistency
3. Iterative labeling
4. Piecewise linear registration
5. Back to 3D space

## Run Example

```matlab
cd registration/distance_based_std
main_registration_distance