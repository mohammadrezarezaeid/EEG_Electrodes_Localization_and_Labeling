%% STEP 2 - Curvature feature extraction on the extracted head surfaces
% =========================================================================
% Second step of the example pipeline. It takes the head surfaces produced
% by step 1 (one surface per intensity threshold) and computes, for every
% vertex of every surface, a set of local shape descriptors.
%
% The idea: an electrode sitting on the scalp is a small bump or trough, so it has a
% curvature signature that differs from the surrounding smooth skin. These
% features are what a classifier later uses to decide "electrode / not
% electrode" at each vertex.
%
% INPUT
%   <folderPath>/result_with_surf*.mat
%       one file per threshold, each containing the sHead structure
%       (.Vertices in SCS metres, .Faces triangle indices)
%
% OUTPUT
%   SavedFeatures_Subject/HC0NN_features_vertices.mat
%       features_vertices : {nSurfaces x 1} cell array.
%       features_vertices{i} is [nVertices x 110] for surface i:
%
%         cols   1 - 10  : per-vertex features (see AllFeatures below)
%         cols  11 - 30  : mean and std of those 10 between 0 to 6 mm neighbourhood
%         cols  31 - 50  : mean and std between 6 mm to 8 mm
%         cols  51 - 70  : mean and std between 8 mm to 10 mm
%         cols  71 - 90  : mean and std between 10 to 12 mm
%         cols  91 -110  : mean and std between 12 to 15 mm
%
%
% DEPENDENCIES
%   GetCurvatures.m (Itzik Ben Shabat, "Patch-Curvature" toolbox) must be
%   on the MATLAB path. It estimates the principal curvatures by fitting a
%   local quadratic patch around each vertex. 
%   (search Curvature Estimationl On triangle mesh in Add-Ons).
% =========================================================================

clc
clear all
close all

%% ===== Paths =====
subjectNum = 23;

% Folder holding the step-1 surfaces for this subject
folderPath = fullfile('Dataset_surface_Extracted_Hist_match', ...
                      sprintf('HC%03d', subjectNum));

saveDir      = 'SavedFeatures_Subject';
saveFileName = fullfile(saveDir, sprintf('HC%03d_features_vertices.mat', subjectNum));

if ~isfolder(folderPath)
    error('Folder for HC%03d is missing: %s', subjectNum, folderPath);
end

% All surface files of this subject, one per intensity threshold.
% dir() returns them in alphabetical order, which for the zero-padded
% "%03d" naming of step 1 is also the order of increasing threshold.
fileList = dir(fullfile(folderPath, 'result_with_surf*.mat'));

if isempty(fileList)
    error('No result_with_surf*.mat files found in %s', folderPath);
end

if ~isfolder(saveDir)
    mkdir(saveDir);
end


%% ===== Parameters =====
% Neighbourhood radii in millimetres. Each radius describes the local shape
% at a different scale, so a feature vector built from all five is
% multi-scale: small radii capture the electrode itself, large ones capture
% the scalp it sits on.
electrodesize = [6, 8, 10, 12, 15];

number_of_thresholds = 20;   % number of thresholds between the two levels

%% ===== Main loop over surfaces =====
tic

features_vertices = cell(number_of_thresholds, 1);

% Counter of vertices whose neighbourhood was too sparse (see fallback below),
% one entry per surface. Useful as a sanity check: a large value means the
% mesh is too coarse relative to the smallest radius.
err_vertices = zeros(number_of_thresholds, 1);

for i = 1:length(fileList)

    % Construct the full file path
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);

    % Load the .mat file
    data_W_electrodes = load(Surface_EXt_filepath);

    % The saved variable is named 'sHead', but reading the first field name
    % instead of hard-coding it keeps the script working if the variable is
    % ever renamed.
    data_W_Names = fieldnames(data_W_electrodes);
    MRI_mask     = data_W_electrodes.(data_W_Names{1});

    % Step 1 stores vertices in SCS metres; x1000 converts to millimetres so
    % that the radii in 'electrodesize' are in the same unit.
    fv.vertices = MRI_mask.Vertices * 1000;
    fv.faces    = MRI_mask.Faces;

    % ----- Per-vertex differential geometry -----
    % PrincipalCurvatures is [2 x nVertices]: row 1 = k1, row 2 = k2,
    % the maximum and minimum normal curvature at each vertex.
    % The second argument (1) is the toolbox's "use the vertex ring" flag.
    [PrincipalCurvatures, PrincipalDir1, PrincipalDir2, ...
     FaceCMatrix, VertexCMatrix, Cmagnitude] = GetCurvatures(fv, 1);

    % Gaussian curvature K = k1*k2.
    % Sign tells the local surface type: K > 0 dome or pit (an electrode),
    % K < 0 saddle, K ~ 0 flat or cylindrical.
    GausianCurvature = PrincipalCurvatures(1,:) .* PrincipalCurvatures(2,:);

    % Mean curvature H = (k1+k2)/2. Sign separates bumps from dents.
    MeanCurvature = mean(PrincipalCurvatures, 1);

    % Shape index (Koenderink & van Doorn): angle of (k1,k2) in the curvature
    % plane, rescaled to [-1, 1]. It encodes the *type* of shape independently
    % of how strongly curved it is: -1 cup, -0.5 rut, 0 saddle, +0.5 ridge,
    % +1 cap. An electrode should sit near +1.
    % Note: undefined (0/0 -> NaN) at umbilic points where k1 == k2.
    ShapeIndex = (2 / pi) * atan((PrincipalCurvatures(1,:) + PrincipalCurvatures(2,:)) ./ ...
                                 (PrincipalCurvatures(1,:) - PrincipalCurvatures(2,:)));

    % Curvedness: the radial distance in the same plane, i.e. how strongly
    % curved the surface is, regardless of shape type. It is the magnitude
    % that ShapeIndex deliberately discards, so the two are complementary.
    Curvedness = sqrt((PrincipalCurvatures(1,:).^2 + PrincipalCurvatures(2,:).^2) / 2);

    % Transpose everything to column-per-feature, row-per-vertex layout
    PrincipalCurvatures = PrincipalCurvatures';
    GausianCurvature    = GausianCurvature';
    MeanCurvature       = MeanCurvature';
    ShapeIndex          = ShapeIndex';
    Curvedness          = Curvedness';

    % [nVertices x 10] feature matrix.
    % The absolute values are included alongside the signed ones so that a
    % classifier can use "how curved" and "curved which way" as separate
    % pieces of evidence.
    AllFeatures = [PrincipalCurvatures      abs(PrincipalCurvatures) ...
                   GausianCurvature         MeanCurvature ...
                   abs(GausianCurvature)    abs(MeanCurvature) ...
                   ShapeIndex               Curvedness];

    features_vertices{i} = [features_vertices{i} AllFeatures];

    % ----- Neighbourhood statistics at each scale -----
    for dIdx = 1:length(electrodesize)

        current_electrodesize = electrodesize(dIdx);

        Mean_AllFeatures_total = zeros(size(AllFeatures));
        Std_AllFeatures_total  = zeros(size(AllFeatures));

        for j = 1:size(fv.vertices,1)

            % Euclidean distance from vertex j to every other vertex.
            % This is a straight-line distance through space, not a distance
            % along the surface, which is a fair approximation at these radii.
            distances = sqrt(sum((fv.vertices - fv.vertices(j,:)).^2, 2));

            % Vertices inside the sphere of radius current_electrodesize
            close_vertices_idx = find(distances <= current_electrodesize);

            % Fallback for sparse regions: with fewer than 5 neighbours the
            % std is meaningless, so take the 5 nearest instead and record
            % that this happened.
            if size(close_vertices_idx,1) < 5
                [~, close_vertices_idx] = mink(distances, 5);
                err_vertices(i,:) = err_vertices(i,:) + 1;
            end

            % Mean and std of each of the 10 features over the neighbourhood.
            % The mean smooths out per-vertex noise from the curvature fit;
            % the std measures how variable the shape is nearby, which is
            % high at an electrode rim and low on flat scalp.
            % Dimension 1 is stated explicitly so a single-row neighbourhood
            % is never collapsed across features by mistake.
            neighborAllFeatures = AllFeatures(close_vertices_idx,:);

            Mean_AllFeatures_total(j,:) = mean(neighborAllFeatures, 1);
            Std_AllFeatures_total(j,:)  = std(neighborAllFeatures, 0, 1);
        end

        % Append this scale's 20 columns to the right of the existing ones
        features_vertices{i} = [features_vertices{i} ...
                                Mean_AllFeatures_total Std_AllFeatures_total];
    end
end

%% ===== Save =====
save(saveFileName, 'features_vertices');

toc