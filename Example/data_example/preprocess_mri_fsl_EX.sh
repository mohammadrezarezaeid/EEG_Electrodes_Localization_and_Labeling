#!/bin/bash

# ============================================================
# MRI Preprocessing using FSL
#
# This script performs preprocessing steps required before
# EEG electrode detection:
#   1) Reorientation
#   2) Registration to MNI space
#   3) Bias field correction
#
# Requirements:
# - FSL (tested with version 6.0.0)
# - MNI head template (mb_mni_avg218T1.nii.gz)
# Author: Mohammadreza Rezaei-Dastjerdehei
# ============================================================

# Load FSL module (for HPC environments)
module load fsl/6.0.0

# ================== INPUT FILE ==================

INPUT=msERBCB1_3-0002-00001-000208-01.nii
REORIENTED=${INPUT%.nii}_reoriented.nii

# ================== STEP 1: REORIENTATION ==================
# Avoid flipping issues before registration

fslswapdim $INPUT RL PA IS $REORIENTED

# ================== STEP 2: MNI REGISTRATION ==================

flirt \
-in $REORIENTED \
-ref mb_mni_avg218T1.nii.gz \
-dof 12 \
-out HC023_elect.nii.gz \
-omat transform_mat_HC023_elect_mni.mat

# ================== STEP 3: BIAS FIELD CORRECTION ==================

fast --nopve -B -O 0 HC023_elect.nii.gz

# Output: HC023_with_mni_restore.nii.gz


echo "Preprocessing completed."