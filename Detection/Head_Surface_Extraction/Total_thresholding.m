% ============================================================
% Compute Global Thresholds (Background & White Matter)
% ============================================================

clc; clear;

%% ================== PARAMETERS ==================

inputDir = 'PATH_TO_BRAINSTORM_ANAT';

subjectIDs = 1:24;
diff_amplitude = 1e6;

%% ================== INIT ==================

whiteLevels = inf(1, numel(subjectIDs));
bgLevels    = zeros(1, numel(subjectIDs));

%% ================== PROCESS ==================

for idx = 1:numel(subjectIDs)

    i = subjectIDs(idx);
    subjectName = sprintf('HC%03d', i);

    fprintf('Processing %s...\n', subjectName);

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

%% ================== GLOBAL VALUES ==================

bgleveltotal = max(bgLevels);

validIdx = isfinite(whiteLevels);
whiteLeveltotal = mean(whiteLevels(validIdx));

%% ================== SAVE ==================

save('whiteLeveltotal.mat', 'whiteLeveltotal');
save('bgleveltotal.mat', 'bgleveltotal');

fprintf('Saved global thresholds.\n');