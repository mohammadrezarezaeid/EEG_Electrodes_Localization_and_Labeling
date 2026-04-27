# Manual Electrode Labeling (MRIcron, MNI Space)

This step provides manually labeled electrode positions using MRIcron after MRI preprocessing and registration to MNI space.

---

## Overview

Electrodes are manually identified and labeled using MRIcron on MRI scans that have already been aligned to MNI space. Therefore, all labeled electrode coordinates are defined in the MNI coordinate system.

The output consists of labeled MRI volumes where each electrode is assigned a unique label.

Then, manual labeling was performed to establish a reliable ground truth for evaluating electrode detection and registration accuracy.

---

## Files

Two labeled datasets are provided:

- `Manual_labeling_MRIcron_MNIspace_256`
- `Manual_labeling_MRIcron_MNIspace_64`

Each file contains a labeled MRI volume with integer values corresponding to electrode indices.

---

## 256-Channel EEG Cap

- Total labeled electrodes: **269**
  
Breakdown:
- **256 electrodes**: standard EEG cap electrodes  
- **2 electrodes**:
  - Reference (Cz)
  - Common (COM)
- **11 electrodes**:
  - Dummy electrodes (used for system configuration and not part of analysis)

A labeling map is used to ensure consistent indexing across all subjects. The electrode labeling follows a standardized EEG cap layout.

![256-channel electrode map](../electrode_map_256.png)

*Figure: 256-channel electrode map adapted from [MDPI, 2022](https://www.mdpi.com/2076-3417/12/12/5991).*

---

## 64-Channel EEG Cap

- Total labeled electrodes: **66**

Breakdown:
- **64 electrodes**: standard EEG cap electrodes  
- **2 electrodes**:
  - Reference
  - Ground

---

## Notes

- All labels are defined in **MNI space** (after preprocessing step)
- These manual annotations are used as ground truth for evaluation
- Label indices must be consistent across all subjects

---

## Dataset Reference

Additional details about the 64 electrodes datasets can be found here:

https://osf.io/w6bh3/

---

## Visualization

An electrode layout (labeling map) is used during manual annotation to maintain consistent labeling across subjects. This map is included in the repository.

