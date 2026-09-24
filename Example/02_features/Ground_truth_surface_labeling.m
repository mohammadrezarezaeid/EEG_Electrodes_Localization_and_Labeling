% ============================================================
% Surface Ground Truth Generation (Electrode-Based Mesh Labeling)
%
% Second part of step 3. The first part transformed the ground truth
% electrode coordinates from MNI into SCS. This part turns those positions
% into per-vertex labels on the surfaces from step 1, so that every vertex
% of every surface is marked as "electrode" or not. These labels are the
% target the classifier is trained against, paired with the features from
% step 2 (same surfaces, same vertex ordering).
%
% Why two passes: the ground truth positions are digitised points floating
% in SCS space, and they do not coincide with any mesh vertex. So the code
% first snaps each electrode to the nearest vertex of each surface, then
% grows a patch of radius current_electrodesize around that snapped point.
% The snapping is redone per surface because each threshold produces a
% different mesh, so the nearest vertex differs from one surface to the next.
%
% INPUT
%   <mainFolderPath>/HC0NN/result_with_surf*.mat
%       the surfaces from step 1, one per intensity threshold
%   <gtFolderPath>/HC0NN_electrode_position_SCS.mat
%       ground truth electrode positions in SCS, from the first part of step 3
%
% OUTPUT
%   Mesh_gt_label/HC0NN_mesh_gt.mat
%       Label_vertices : {nFiles x 1} cell array. Label_vertices{i} is a
%       column of vertex indices belonging to an electrode patch on
%       surface i, stacked over all electrodes.
% ============================================================

clc;
clear;
close all;

tic

%% ================== PATHS ==================

subjectNum = 23;
subjectName = sprintf('HC%03d', subjectNum);

mainFolderPath = 'Dataset_surface_Extracted_Hist_match'; % step-1 surfaces
gtFolderPath   = 'HC023_electrode_position_SCS'; % step-3 positions

outputFolder   = 'Mesh_gt_label';


folderPath = fullfile(mainFolderPath, subjectName);

if ~isfolder(folderPath)
   fprintf('Folder for %s is missing. Skipping.\n', subjectName);
end

fileList = dir(fullfile(folderPath, 'result_with_surf*.mat'));

if isempty(fileList)
   fprintf('No files found for %s. Skipping.\n', subjectName);
end


gtFile = fullfile(gtFolderPath, ...
        sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));

if ~isfile(gtFile)
    fprintf('GT missing for %s. Skipping.\n', subjectName);
end


if ~exist(outputFolder, 'dir')
   mkdir(outputFolder);
end

%% ================== PARAMETERS ==================
% Radius in millimetres of the patch grown around each electrode. It sets
% how much of the mesh counts as "electrode" in the labels, so it should
% match the physical size of the electrode on the scalp. Note this is the
% same value as the smallest radius in the step-2 feature set.

current_electrodesize = 6; % neighborhood radius (mm)

 %% ================== LOAD GROUND TRUTH ==================
% Reading the first field name instead of hard-coding it keeps the script
% working if the saved variable is ever renamed
gtStruct = load(gtFile);
gtNames  = fieldnames(gtStruct);
% [nElectrodes x 3] in SCS millimetres
Position_countour_electrodes = gtStruct.(gtNames{1});

%% ================== FIND CLOSEST VERTICES ==================
% Pass 1: snap every electrode onto the nearest vertex of every surface.
% closest_data is [nElectrodes x nFiles]; entry {j,i} describes electrode j
% on surface i.
closest_data = cell(size(Position_countour_electrodes,1), length(fileList));

    for i = 1:length(fileList)

        filePath = fullfile(folderPath, fileList(i).name);
        data = load(filePath);

        fieldName = fieldnames(data);
        MRI_mask = data.(fieldName{1});

        vertices = MRI_mask.Vertices * 1000;
        faces    = MRI_mask.Faces;

        for j = 1:size(Position_countour_electrodes, 1)

            electrode_pos = Position_countour_electrodes(j, :);

            distances = sqrt(sum((vertices - electrode_pos).^2, 2));

            [~, closest_idx] = min(distances);

            closest_data{j, i}.verticegt = vertices(closest_idx, :);

        end
    end

%% ================== LABEL MESH REGION ==================
% Pass 2: grow a patch of radius current_electrodesize around each anchor
% and record which vertices and faces it covers.

Label_vertices = cell(length(fileList), 1);

    for i = 1:length(fileList)

        filePath = fullfile(folderPath, fileList(i).name);
        data = load(filePath);

        fieldName = fieldnames(data);
        MRI_mask = data.(fieldName{1});

        vertices = MRI_mask.Vertices * 1000;
        faces    = MRI_mask.Faces;

        for j = 1:size(closest_data,1)

            electrode_pos = closest_data{j, i}.verticegt;

            distances = sqrt(sum((vertices - electrode_pos).^2, 2));

            close_vertices_idx = find(distances <= current_electrodesize);

            close_faces_logic = any(ismember(faces, close_vertices_idx), 2);

            closest_data{j, i}.vertices   = vertices(close_vertices_idx, :);
            closest_data{j, i}.faceslogic = faces(close_faces_logic, :);

            Label_vertices{i} = [Label_vertices{i}; close_vertices_idx];

        end
    end

%% ================== SAVE ==================


save(fullfile(outputFolder, ...
        sprintf('HC%03d_mesh_gt.mat', subjectNum)), ...
        'Label_vertices');

toc