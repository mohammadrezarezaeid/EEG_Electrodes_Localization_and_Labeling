%% STEP 1 - Head-surface extraction at multiple intensity thresholds
% =========================================================================
% This is the first step of the example pipeline. It starts from a single
% T1-weighted MRI (NIfTI) and produces a set of closed head surfaces, one
% for each intensity threshold.
%
% INPUT (in ./data)
%   HC023_with_mni_restore.nii.gz  T1-weighted MRI of subject HC023
%   bgleveltotal.mat               variable 'bgleveltotal'   : lowest threshold
%   whiteLeveltotal.mat            variable 'whiteLeveltotal': highest threshold
%
% WHAT IT DOES
%   1. Imports the MRI into a Brainstorm protocol and runs an affine MNI
%      normalization (SPM 'maff8'). This also defines the fiducials
%      (NAS/LPA/RPA), which the SCS coordinate system needs.
%   2. Sweeps the binarization threshold linearly from bgleveltotal to
%      whiteLeveltotal in nLevels steps. At each threshold it builds a head
%      mask, cleans it, and triangulates it into a closed surface in SCS
%      coordinates (meters).
%
% OUTPUT (in ./output/HC023/step1_surfaces)
%   Dataset_surface_Extracted_Hist_match\HC023 folder  containing one file 
%                                                           per threshold, each holding  
%                                                           a surface withvertices and faces  
%
%   Dataset_surface_Extracted_Hist_match.mat           normalized Brainstorm MRI structure
%
% REQUIREMENTS
%   - MATLAB (tested with: 2023)
%   - Brainstorm on the MATLAB path,
%     with a database folder already configured (run 'brainstorm' once
%     interactively if you have never used it)
% =========================================================================
clear; clc;

%% ===== 0. Paths =====
% Every path is relative to this script, so the example runs wherever the
% repository is cloned.

subjectName = 'HC023';
fprintf('Surface extraction: %s\n', subjectName);

mriFilePath = [subjectName '_with_mni_restore.nii.gz'];
outputDir = 'Dataset_surface_Extracted_Hist_match';

% Create output directory if it doesn't exist
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

outputSubDir = fullfile(outputDir, subjectName);
if ~exist(outputSubDir, 'dir')
    mkdir(outputSubDir);
end

% Stop now if the input is missing. Otherwise the script would fail
% later with a confusing "undefined variable sMri" error.
if ~isfile(mriFilePath)
    error('Input MRI not found: %s', mriFilePath);
end

%% ===== 1. Parameters =====

nVertices = 500000; % max vertices of the final surface
hist_reolution=20; % number of thresholds between the two levels
erodeFactor = 0; % morphological opening radius (0 = off)
fillFactor = 2; % hole-filling strength passed to tess_fillholes

% Intensity thresholds. The histogram-matched background and white levels
% are loaded explicitly by name so the source of each variable is visible

load('bgleveltotal.mat') % Air/background threshold extracted from training dataset
load('whiteLeveltotal.mat') % White matter threshold extracted from training dataset

% Define surface extraction periods
Surface_ext_period=linspace(bgleveltotal, whiteLeveltotal, hist_reolution);


%% ===== 2. Start Brainstorm and select a dedicated protocol =====
brainstorm

% Use a dedicated protocol so the example never touches the user's own data
protocolName = 'SurfaceExtractionExample';
iProtocol = bst_get('Protocol', protocolName);
if isempty(iProtocol)
    gui_brainstorm('CreateProtocol', protocolName, 0, 0);  % no default anatomy/channels
else
    gui_brainstorm('SetCurrentProtocol', iProtocol);
end


%% ===== 3. Import MRI and MNI-normalize =====

sMri = mni_normalization_brainstorm_EX(subjectName, mriFilePath,outputDir);


%% ===== 4. Extract one head surface per threshold =====

for level = Surface_ext_period

    tic;

    sHead = headsurfext_EX(sMri, nVertices, ...
                            erodeFactor, fillFactor, level);

    save(fullfile(outputSubDir, ...
            sprintf('result_with_surf%03d.mat', round(level))), ...
            'sHead');

    toc;
end

fprintf('Done. Surfaces saved in:\n  %s\n', outputSubDir);