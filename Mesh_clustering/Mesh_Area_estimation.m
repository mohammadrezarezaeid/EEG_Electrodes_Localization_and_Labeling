%%
clc
clear all
close all

%%
tic
% Define the main folder path
mainFolderPath = 'C:\PhD\Aim1_final_code\Dataset_surface_Extracted_Hist_match_64_electrodes\';

main_gt_filename='C:\PhD\Aim1_final_code\manual_labeling_gt_SCS_64_elect\';
%% Parameters

current_electrodesize = 6;

%%

% Loop through each subject from HC008 to HC024
for subjectNum = 9
% Generate the subject folder path based on the subject number
folderPath = fullfile(mainFolderPath, sprintf('HC%03d', subjectNum));
    
% Check if the subject folder exists
if ~isfolder(folderPath)
   fprintf('Folder for HC%03d is missing. Skipping.\n', subjectNum);
   continue;
end
    
% Get a list of all the .mat files in the folder that match 'result_with_surf*.mat'
fileList = dir(fullfile(folderPath, 'result_with_surf*.mat'));
    
% Check if there are any files to process
if isempty(fileList)
   fprintf('No files found for HC%03d. Skipping.\n', subjectNum);
   continue;
end




%%

gt_filename = fullfile(main_gt_filename, sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));
    
% Check if the subject folder exists
if isempty(gt_filename)
   fprintf('Folder for gt HC%03d is missing. Skipping.\n', subjectNum);
   continue;
end

% gt_filename='C:\PhD\Aim1_final_code\manual_labeling_gt_SCS\HC008_electrode_position_SCS.mat';

% Load the .mat file into a structure
gtStruct = load(gt_filename);

% Get the field names of the structure
gtNames = fieldnames(gtStruct);

% Extract the data and assign it to an array
Position_countour_electrodes=gtStruct.(gtNames{1});



%%
% Loop through each file and apply the code

for i = 1:length(fileList)

    % Construct the full file path
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);
    
    % Load the .mat file
    data_W_electrodes = load(Surface_EXt_filepath);

    % Get the field names of the structure
    data_W_Names = fieldnames(data_W_electrodes);

    % Extract the data and assign it to an array (assuming the field contains MRI_mask)
    MRI_mask = data_W_electrodes.(data_W_Names{1});
    

    vertices=MRI_mask.Vertices*1000;
    faces=MRI_mask.Faces;

    for j = 1:size(Position_countour_electrodes, 1)
        % Get current electrode position
        electrode_pos = Position_countour_electrodes(j, :);

        % Calculate the distance between the current electrode and all vertices
        distances_fromGT = sqrt(sum((vertices - electrode_pos).^2, 2));

        % Find the indices of vertices within the distance threshold
        [~,close_vertices_idx] = min(distances_fromGT);

        closest_data{j, i}.verticegt=vertices(close_vertices_idx, :);

    end
end


%%

Label_vertices=cell(20, 1);


for i = 1:length(fileList)

    % Construct the full file path
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);
    
    % Load the .mat file
    data_W_electrodes = load(Surface_EXt_filepath);

    % Get the field names of the structure
    data_W_Names = fieldnames(data_W_electrodes);

    % Extract the data and assign it to an array (assuming the field contains MRI_mask)
    MRI_mask = data_W_electrodes.(data_W_Names{1});
    

    vertices=MRI_mask.Vertices*1000;
    faces=MRI_mask.Faces;

    for j = 1:size(closest_data, 1)
        % Get current electrode position
        electrode_pos = closest_data{j, i}.verticegt;

        % Calculate the distance between the current electrode and all vertices
        distances = sqrt(sum((vertices - electrode_pos).^2, 2));

        % Find the indices of vertices within the distance threshold
        close_vertices_idx = find(distances <= current_electrodesize);
        
        % Find the faces that use these vertices
        % close_faces_idx = find(any(ismember(faces, close_vertices_idx), 2));

        close_faces_idx_logic=any(ismember(faces, close_vertices_idx), 2);
        
        % Store the closest vertices and faces for this point and this mesh
        closest_data{j, i}.vertices = vertices(close_vertices_idx, :);
        closest_data{j, i}.faceslogic = faces(close_faces_idx_logic, :);

        % Extract the vertices of the selected faces
        v1 = vertices(faces(close_faces_idx_logic,1), :);
        v2 = vertices(faces(close_faces_idx_logic,2), :);
        v3 = vertices(faces(close_faces_idx_logic,3), :);

        % Calculate the vectors for two edges of the triangle
        edge1 = v2 - v1;
        edge2 = v3 - v1;

        % Compute the cross product of the edge vectors
        cross_prod = cross(edge1, edge2, 2);

        % Compute the area of the triangles
        areas = 0.5 * sqrt(sum(cross_prod.^2, 2));

        total_area(j,i)=sum(areas);


    end
end


end
toc