% ============================================================
% Ground Truth Transformation: MNI → SCS (Batch Processing)
%
% Converts ground truth electrode coordinates from MNI space
% to SCS using Brainstorm transformation matrices
% ============================================================

clc; clear;

%% ================== PARAMETERS ==================

% Base directories (update these paths)
baseMriPath = 'PATH_TO_BRAINSTORM_ANAT';
baseGtPath  = 'PATH_TO_GT_MNI';
outputDir   = 'PATH_TO_OUTPUT_SCS';

% Subject range
subjectIDs = 3:23;

%% ================== PREPARE OUTPUT ==================

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

%% ================== PROCESS ==================

for id = subjectIDs

    subjectName = sprintf('HC%03d', id);
    fprintf('Processing %s...\n', subjectName);

    % File paths
    mriFile = fullfile(baseMriPath, subjectName, ...
        sprintf('subjectimage_%s_elect_restore_cut.mat', subjectName));

    gtFile = fullfile(baseGtPath, ...
        sprintf('EEG_64_Cap_Coordinates_%s.xlsx', subjectName));

    % Check existence
    if ~isfile(mriFile)
        warning('Missing MRI file: %s', mriFile);
        continue;
    end

    if ~isfile(gtFile)
        warning('Missing GT file: %s', gtFile);
        continue;
    end

    %% ================== TRANSFORMATION ==================

    [posSCS, transform] = Transfom2SCS(mriFile, gtFile);

    %% ================== SAVE ==================

    outputPosFile = fullfile(outputDir, ...
        sprintf('%s_electrode_position_SCS.mat', subjectName));

    outputTransFile = fullfile(outputDir, ...
        sprintf('Transformation2SCS_%s.mat', subjectName));

    save(outputPosFile, 'posSCS');
    save(outputTransFile, 'transform');

end

fprintf('All subjects processed.\n');