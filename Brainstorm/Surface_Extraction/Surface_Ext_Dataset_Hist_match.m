% Define directories
inputDir = 'C:\PhD\phd_curve2\brainstorm\Protocol04\anat';
outputDir = 'C:\PhD\Aim1_final_code\Dataset_surface_Extracted_Hist_match_64_electrodes'; 

% Create output directory if it doesn't exist
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

% File IDs from HC003 to HC023 and parameters
fileIDs = 1:23;
diff_amplitude = 1e6;
nVertices = 500000;
erodeFactor = 0;
fillFactor = 2;

hist_reolution=20;


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

whiteLeveltotal = min(whiteLevels_with_clean);

%%

% Define surface extraction periods
Surface_ext_period=linspace(bgleveltotal, whiteLeveltotal, hist_reolution);

% Loop through each file ID

%parfor
for i = fileIDs

    fprintf('The subject is %d ', i);

    % Create subfolder name based on ID (HC008, HC009, ..., HC024)
    subfolderName = sprintf('HC%03d', i);

    % Define file names
    withFile = sprintf('subjectimage_HC%03d_elect_restore_cut.mat', i);

    % Full paths to the input files
    withFilePath = fullfile(inputDir,subfolderName, withFile);

    % Check if the files exist, otherwise issue a warning and skip
    if ~exist(withFilePath, 'file')
        warning('File not found: %s. Skipping HC%03d_with_mni_restore.', withFilePath, i);
        continue;
    end

    % Create subfolder for each file ID (HC008, HC009, ..., HC024)
    outputsubfolderPath = fullfile(outputDir, subfolderName);
    if ~exist(outputsubfolderPath, 'dir')
        mkdir(outputsubfolderPath); % Create subfolder if it doesn't exist
    end


    for j=Surface_ext_period
        tic
        % Extract surfaces
        [sHeadwith] = headsurfext(withFilePath, nVertices, erodeFactor, fillFactor, j);

        % Save results in the subfolder
        save(fullfile(outputsubfolderPath, sprintf('result_with_surf%03d.mat', round(j))), 'sHeadwith');
        toc
    end

end

