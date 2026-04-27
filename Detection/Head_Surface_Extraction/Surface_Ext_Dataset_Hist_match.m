% ============================================================
% Head Surface Extraction using Histogram Matching
% ============================================================

clc; clear;

%% ================== PARAMETERS ==================

inputDir  = 'PATH_TO_BRAINSTORM_ANAT';
outputDir = 'PATH_TO_OUTPUT';

subjectIDs = 1:23;

diff_amplitude = 1e6;
nVertices      = 500000;
erodeFactor    = 0;
fillFactor     = 2;
hist_resolution = 20;

%% ================== PREPARE OUTPUT ==================

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

whiteLevels = inf(1, numel(subjectIDs));
bgLevels    = zeros(1, numel(subjectIDs));

%% ================== HISTOGRAM ANALYSIS ==================

for idx = 1:numel(subjectIDs)

    i = subjectIDs(idx);
    subjectName = sprintf('HC%03d', i);

    fprintf('Histogram processing: %s\n', subjectName);

    filePath = fullfile(inputDir, subjectName, ...
        sprintf('subjectimage_%s_elect_restore_cut.mat', subjectName));

    if ~isfile(filePath)
        warning('Missing file: %s', filePath);
        continue;
    end

    sMri = load(filePath);

    [start_idx, ~] = findhistPeriod(filePath, diff_amplitude);

    bgLevels(idx)    = sMri.Histogram.fncX(start_idx);
    whiteLevels(idx) = sMri.Histogram.whiteLevel;

end

%% ================== GLOBAL THRESHOLDS ==================

bgleveltotal = max(bgLevels);

validIdx = isfinite(whiteLevels);
whiteLeveltotal = min(whiteLevels(validIdx));

Surface_ext_period = linspace(bgleveltotal, whiteLeveltotal, hist_resolution);

%% ================== SURFACE EXTRACTION ==================

for i = subjectIDs

    subjectName = sprintf('HC%03d', i);
    fprintf('Surface extraction: %s\n', subjectName);

    filePath = fullfile(inputDir, subjectName, ...
        sprintf('subjectimage_%s_elect_restore_cut.mat', subjectName));

    if ~isfile(filePath)
        warning('Missing file: %s', filePath);
        continue;
    end

    outputSubDir = fullfile(outputDir, subjectName);
    if ~exist(outputSubDir, 'dir')
        mkdir(outputSubDir);
    end

    for level = Surface_ext_period

        tic;

        sHead = headsurfext(filePath, nVertices, ...
                            erodeFactor, fillFactor, level);

        save(fullfile(outputSubDir, ...
            sprintf('result_with_surf%03d.mat', round(level))), ...
            'sHead');

        toc;

    end
end