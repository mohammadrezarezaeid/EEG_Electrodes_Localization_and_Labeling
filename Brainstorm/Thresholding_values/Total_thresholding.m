% % Define directories
inputDir = 'C:\PhD\phd_curve2\brainstorm\Protocol04\anat';


% File IDs from HC008 to HC024 and parameters
fileIDs = 1:24;
diff_amplitude = 1e6;


% Preallocate arrays for storing histogram data
whiteLevels_with = inf(1, numel(fileIDs));
bgLevelwith = zeros(1, numel(fileIDs));

% Loop over each file ID and process MRI files
for idx = 1:numel(fileIDs)
    i = fileIDs(idx);
    fprintf('Processing subject HC%03d...\n', i);

    % Create subfolder name
    subfolderName = sprintf('HC%03d', i);

    % Define file names
    withFile = sprintf('subjectimage_HC%03d_elect_restore_cut.mat', i);
    
    % Full paths to the input files
    withFilePath = fullfile(inputDir, subfolderName, withFile);
    
    % Check if both files exist, otherwise issue a warning and skip
    if ~exist(withFilePath, 'file')
        warning('Files missing for HC%03d. Skipping...', i);
        continue;
    end
    
    % Load data and extract histogram for 'with_mni_restore'
    sMriwith = load(withFilePath);
    [start_idx_with, end_idx_with] = findhistPeriod(withFilePath, diff_amplitude);
    bgLevelwith(idx) = sMriwith.Histogram.fncX(start_idx_with);
    whiteLevels_with(idx) = sMriwith.Histogram.whiteLevel;

end


bgleveltotal = max(bgLevelwith);

% Clean up invalid data
validIndices_with = isfinite(whiteLevels_with);
whiteLevels_with_clean = whiteLevels_with(validIndices_with);

whiteLeveltotal = mean(whiteLevels_with_clean);
%%

% Save results in the subfolder
save("whiteLeveltotal.mat", 'whiteLeveltotal');
save("bgleveltotal.mat", 'bgleveltotal');

