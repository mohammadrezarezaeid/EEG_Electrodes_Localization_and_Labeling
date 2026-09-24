% ============================================================
% Ground Truth Transformation: MNI → SCS
%
% Converts ground truth electrode coordinates from MNI space
% to SCS using Brainstorm transformation matrices
%
% First part of step 3 of the example pipeline. The ground truth electrode
% positions come from an external digitisation in MNI space, while the
% surfaces from step 1 live in SCS (Subject Coordinate System, defined by
% the NAS/LPA/RPA fiducials). The two must be in the same frame before
% any position can be compared with a surface vertex, so this step maps
% the ground truth into SCS using the transformations stored in the
% normalised MRI structure produced in step 1.
%
% INPUT
%   Dataset_surface_Extracted_Hist_match.mat
%       Brainstorm MRI structure saved by the MNI normalisation in step 1.
%       It carries the MNI transformation and the SCS fiducials, which is
%       what makes the MNI -> SCS mapping possible.
%   HC023_electrode_position.xlsx
%       Ground truth electrode coordinates in MNI space, one row per
%       electrode.
%
% OUTPUT (in HC023_electrode_position_SCS/)
%   HC023_electrode_position_SCS.mat   posSCS    : electrode positions in SCS
%   Transformation2SCS_HC023.mat       transform : the transformation used,
%                                      saved separately so the mapping can be
%                                      reapplied or inverted later without
%                                      redoing it
%
% DEPENDENCY
%   Transfom2SCS.m
% ============================================================

clc
clear all
close all

%% ===== Paths =====

% Normalised MRI structure from step 1
mriFile = "Dataset_surface_Extracted_Hist_match.mat";
% Ground truth electrode coordinates in MNI space
gtFile = "HC023_electrode_position.xlsx";
% Where the transformed positions and the transformation are written
outputDir   = 'HC023_electrode_position_SCS';

% Check existence
if ~isfile(mriFile)
    warning('Missing MRI file: %s', mriFile);
end

if ~isfile(gtFile)
    warning('Missing GT file: %s', gtFile);
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% Subject number
subjectIDs = 23;

subjectName = sprintf('HC%03d', subjectIDs);
fprintf('Processing %s...\n', subjectName);


%% ================== TRANSFORMATION ==================
% posSCS    : ground truth electrode positions expressed in SCS
% transform : the transformation applied, kept so that the same mapping
%             can be reused or inverted without recomputing it

[posSCS, transform] = Transfom2SCS(mriFile, gtFile);

%% ================== SAVE ==================
% Positions and transformation are stored in separate files so that either
% one can be loaded on its own by the later steps

outputPosFile = fullfile(outputDir, ...
        sprintf('%s_electrode_position_SCS.mat', subjectName));

outputTransFile = fullfile(outputDir, ...
        sprintf('Transformation2SCS_%s.mat', subjectName));

save(outputPosFile, 'posSCS');
save(outputTransFile, 'transform');


fprintf('subjects processed.\n');