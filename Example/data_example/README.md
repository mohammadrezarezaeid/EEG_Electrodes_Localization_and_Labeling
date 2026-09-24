# Example data — subject HC023

Everything the example pipeline needs for one subject. HC023 was **not** used
to train any of the models in this repository; it is the held-out subject of
the evaluation reported in the article.

## Files

### `HC023_with_mni_restore.nii`

The T1 MR volume of the subject, after preprocessing. This is the input of
the pipeline: every later step starts from this file.

### `HC023_electrode_position.xlsx`

The ground truth: where the electrodes really are, marked by hand.
Nothing in the pipeline reads this file until the final evaluation. The
detection and labeling steps never see it.

### `preprocessing_fsl.sh`

The FSL commands that produced `HC023_with_mni_restore.nii` from the raw scan.

It is here for two reasons: so the preprocessing can be repeated exactly, with
the tool versions and parameters on record rather than described in prose, and
so the same treatment can be applied to a new subject before running the
pipeline on it.

The raw scan is not included. This script documents how it was transformed;
the `.nii` file above is the result, and it is all the pipeline needs.

## Using your own subject

Run `preprocessing_fsl.sh` on your own T1, then start the pipeline at step 1
with the volume it produces. Ground truth is only needed if you want to
evaluate the result; without it, the pipeline still outputs electrode
positions, it simply cannot score them.
