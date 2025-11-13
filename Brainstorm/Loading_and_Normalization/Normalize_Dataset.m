% Path to the datasets
datasetPath = 'C:\PhD\Aim1_final_code\Datasets_64_electrodes\MRI_without_neck';

% Loop through subjects 8 to 20
for i = 3:23
    % Create the subject name based on the number format
    if i < 10
        subjectName = ['HC00' num2str(i)];
    else
        subjectName = ['HC0' num2str(i)];
    end
    
    % Define the two possible file suffixes
    fileSuffixes = {'_elect_restore_cut.nii.gz'};
    
    % Loop through both file suffixes
    for j = 1:length(fileSuffixes)
        % Create the full file path
        mriFilePath = fullfile(datasetPath, [subjectName fileSuffixes{j}]);
        
        % Check if the file exists before processing
        if isfile(mriFilePath)
            % Call the previous function to process MRI and normalize
            mni_normalization_brainstorm(subjectName, mriFilePath);
        else
            warning('File does not exist: %s', mriFilePath);
        end
    end
end
