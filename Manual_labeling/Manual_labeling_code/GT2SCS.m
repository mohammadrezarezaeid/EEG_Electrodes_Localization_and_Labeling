% Define paths and range
base_mri_path = 'C:\PhD\phd_curve2\brainstorm\Protocol04\anat\';
base_gt_path = 'C:\PhD\Aim1_final_code\Datasets_64_electrodes\Electrodes_coordinate_MNI\';
output_dir = 'C:\PhD\Aim1_final_code\manual_labeling_gt_SCS_64_elect\'; % Define the directory to save outputs
start_idx = 3; % Starting from HC003
end_idx = 23; % Ending at HC023

for id = start_idx:end_idx
    % Construct the HC ID with leading zeros
    hc_id = sprintf('HC%03d', id);
    
    % Construct file paths
    mri_filename = fullfile(base_mri_path, hc_id, sprintf('subjectimage_%s_elect_restore_cut.mat', hc_id));
    gt_filename = fullfile(base_gt_path, sprintf('EEG_64_Cap_Coordinates_%s.xlsx', hc_id));
    
    % Check if both MRI and GT files exist
    if isfile(mri_filename) && isfile(gt_filename)
        fprintf('Processing %s...\n', hc_id);
        
        % Apply the Transfom2SCS function
        [Position_countour_electrodes_SCS, Transformation] = Transfom2SCS(mri_filename, gt_filename);
        
        % Define output filenames
        output_pos_filename = fullfile(output_dir, sprintf('%s_electrode_position_SCS.mat', hc_id));
        output_trans_filename = fullfile(output_dir, sprintf('Transformation2SCS_%s.mat', hc_id));
        
        % Save the results
        save(output_pos_filename, 'Position_countour_electrodes_SCS');
        save(output_trans_filename, 'Transformation');
    else
        fprintf('Skipping %s, files missing...\n', hc_id);
    end
end

