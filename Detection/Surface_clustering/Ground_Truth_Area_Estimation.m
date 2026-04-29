%% ------------------------------------------------------------------------
% Surface Clustering - Ground Truth Area Estimation
%
% This script:
% 1. Finds the closest mesh vertex to each ground-truth electrode position
% 2. Extracts a local surface region around that vertex
% 3. Computes the total surface area using triangle faces
%
% Author: Mohammadreza Rezaei
% -------------------------------------------------------------------------

clc;clear all;close all

%% ----------------------------- Paths ------------------------------------
% Update these paths based on your environment

mainFolderPath = 'PATH_to_classification_output\';
mainGTPath     = 'PATH_to_groundtuth\';

%% --------------------------- Parameters ---------------------------------
current_electrodesize = 8;
subjectNum = 9;
numsurfaces=20;
Label_vertices = cell(numsurfaces, 1);

%% --------------------------- Loading Data ---------------------------------

% Generate the subject folder path
folderPath = fullfile(mainFolderPath, sprintf('HC%03d', subjectNum));
    
% Check if the subject folder exists
if ~isfolder(folderPath)
   fprintf('Folder for HC%03d is missing. Skipping.\n', subjectNum);
end
    
% Get all matching surface files
fileList = dir(fullfile(folderPath, 'result_with_surf*.mat'));
    
% Check if files exist
if isempty(fileList)
   fprintf('No files found for HC%03d. Skipping.\n', subjectNum);
end

gt_filename = fullfile(main_gt_filename, ...
    sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));
    
if isempty(gt_filename)
   fprintf('Folder for gt HC%03d is missing. Skipping.\n', subjectNum);   
end

% Load GT file
gtStruct = load(gt_filename);
gtNames  = fieldnames(gtStruct);

% Extract electrode positions
Position_countour_electrodes = gtStruct.(gtNames{1});

%% -------- Step 1: Closest Vertex to Each Electrode -------------------

for i = 1:length(fileList)

    
    % Load surface file
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);
    data_W_electrodes = load(Surface_EXt_filepath);

    data_W_Names = fieldnames(data_W_electrodes);
    MRI_mask = data_W_electrodes.(data_W_Names{1});
        
    vertices = MRI_mask.Vertices * 1000;
    faces    = MRI_mask.Faces;

    for j = 1:size(Position_countour_electrodes, 1)

        electrode_pos = Position_countour_electrodes(j, :);

        % Compute distance to all vertices
        distances_fromGT = sqrt(sum((vertices - electrode_pos).^2, 2));

        % Find closest vertex
        [~, close_vertices_idx] = min(distances_fromGT);

        closest_data{j, i}.verticegt = vertices(close_vertices_idx, :);

    end
end

%% -------- Step 2: Local Surface Extraction and Area Estimation for each surface for each electrode --------------------

for i = 1:length(fileList)

    % Load surface file again
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);
    data_W_electrodes = load(Surface_EXt_filepath);

    data_W_Names = fieldnames(data_W_electrodes);
    MRI_mask = data_W_electrodes.(data_W_Names{1});
        
    vertices = MRI_mask.Vertices * 1000;
    faces    = MRI_mask.Faces;

    for j = 1:size(closest_data, 1)

        electrode_pos = closest_data{j, i}.verticegt;

        % Distance to all vertices
        distances = sqrt(sum((vertices - electrode_pos).^2, 2));

        % Select nearby vertices
        close_vertices_idx = find(distances <= current_electrodesize);
            
        % Find faces connected to these vertices
        close_faces_idx_logic = any(ismember(faces, close_vertices_idx), 2);
            
        % Store region
        closest_data{j, i}.vertices   = vertices(close_vertices_idx, :);
        closest_data{j, i}.faceslogic = faces(close_faces_idx_logic, :);

         % Triangle vertices
         v1 = vertices(faces(close_faces_idx_logic,1), :);
         v2 = vertices(faces(close_faces_idx_logic,2), :);
         v3 = vertices(faces(close_faces_idx_logic,3), :);

         % Triangle edges
         edge1 = v2 - v1;
         edge2 = v3 - v1;

         % Cross product
         cross_prod = cross(edge1, edge2, 2);

         % Triangle areas
         areas = 0.5 * sqrt(sum(cross_prod.^2, 2));

         % Total area for each electrode for each surface (269*20)
         total_area(j, i) = sum(areas);

   end
end
