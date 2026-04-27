% ============================================================
% Normalize MRI Dataset using Brainstorm
%
% Applies Brainstorm MNI normalization to all subjects
% ============================================================

clc; clear;

%% ================== PARAMETERS ==================

datasetPath = 'PATH_TO_DATASET';  % <-- update this
fileSuffix = '_elect_restore_cut.nii.gz'; % <-- update this

subjectIDs = 3:23; % <-- update this

%% ================== PROCESS ==================

for i = subjectIDs

    subjectName = sprintf('HC%03d', i);
    mriFilePath = fullfile(datasetPath, [subjectName fileSuffix]);

    if isfile(mriFilePath)
        fprintf('Processing %s...\n', subjectName);

        mni_normalization_brainstorm(subjectName, mriFilePath);

    else
        warning('File not found: %s', mriFilePath);
    end

end