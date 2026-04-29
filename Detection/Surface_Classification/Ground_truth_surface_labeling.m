% ============================================================
% Surface Ground Truth Generation (Electrode-Based Mesh Labeling)
% ============================================================

clc;
clear;
close all;

tic

%% ================== PATHS ==================

mainFolderPath = 'PATH_TO_SURFACE_DATA';
gtFolderPath   = 'PATH_TO_GT_SCS';

outputFolder   = 'PATH_TO_SAVE_MESH_GT';

%% ================== PARAMETERS ==================

current_electrodesize = 6; % neighborhood radius (mm)

subjectIDs = 3:23;

%% ================== PROCESS ==================

for subjectNum = subjectIDs

    subjectName = sprintf('HC%03d', subjectNum);

    folderPath = fullfile(mainFolderPath, subjectName);

    if ~isfolder(folderPath)
        fprintf('Folder for %s is missing. Skipping.\n', subjectName);
        continue;
    end

    fileList = dir(fullfile(folderPath, 'result_with_surf*.mat'));

    if isempty(fileList)
        fprintf('No files found for %s. Skipping.\n', subjectName);
        continue;
    end

    %% ================== LOAD GROUND TRUTH ==================

    gtFile = fullfile(gtFolderPath, ...
        sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));

    if ~isfile(gtFile)
        fprintf('GT missing for %s. Skipping.\n', subjectName);
        continue;
    end

    gtStruct = load(gtFile);
    gtNames  = fieldnames(gtStruct);
    Position_countour_electrodes = gtStruct.(gtNames{1});

    %% ================== FIND CLOSEST VERTICES ==================

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

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    save(fullfile(outputFolder, ...
        sprintf('HC%03d_mesh_gt.mat', subjectNum)), ...
        'Label_vertices');

end

toc