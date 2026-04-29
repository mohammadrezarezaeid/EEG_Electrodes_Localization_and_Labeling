%% ========================================================================
%  EEG Electrode Localization Pipeline
%  ------------------------------------------------------------------------
%  This script performs:
%   1. Surface loading
%   2. Predicted region extraction
%   3. Region-growing segmentation
%   4. Patch filtering based on area statistics
%   5. Multi-surface projection
%   6. DBSCAN clustering
%   7. Electrode localization evaluation
%
%  Author: Mohammadreza Rezaei-Dastjerdehei
%  ========================================================================

clearvars;
close all;

%% ========================= PARAMETERS ===================================

subjectNum  = 24;
subjectName = sprintf('HC%03d_Detection', subjectNum);

params.dbscanEpsilon       = 8; % DBSCAN paremeters
params.dbscanMinPts        = 3; % DBSCAN paremeters
params.falsePositiveThresh = 10; % Threshold for false positive
params.zThreshold          = -75; % Threshold for removing neck
params.excludeSurfaceIdx = 16; % Detection output File from DL model related to subject (for example here subject 16)

%% =========================== PATHS ======================================

surfaceFolder = fullfile( ...
    'Dataset_surface_Extracted_Hist_match', ...
    sprintf('HC%03d', subjectNum));

predictionFolder = 'nonweighted';

groundTruthFile = fullfile( ...
    'manual_labeling_gt_SCS_new', ...
    sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));

areaStatisticsFile = 'total_area_HC008.mat';

%% ====================== LOAD GROUND TRUTH ===============================

fprintf('Loading ground truth...\n');

gtStruct   = load(groundTruthFile);
gtFields   = fieldnames(gtStruct);
groundTruth = gtStruct.(gtFields{1});

groundTruth(259:end, :) = [];

%% ========================= LOAD SURFACES ================================

fprintf('Loading surface files...\n');

surfaceFiles = dir(fullfile(surfaceFolder, 'result_with_surf*.mat'));
numSurfaces  = length(surfaceFiles);

%% ==================== EXTRACT PREDICTED PATCHES =========================

fprintf('Extracting predicted regions...\n');

detectedRegions = cell(numSurfaces, 1);

for surfaceIdx = 1:numSurfaces

    %% Load prediction results
    predictionFilename = sprintf( ...
        'predicted_exclude_idx_%d.mat', ...
        params.excludeSurfaceIdx);

    predictionPath = fullfile( ...
        predictionFolder, ...
        ['Predicted_Cell_' num2str(surfaceIdx)], ...
        predictionFilename);

    predictionData = load(predictionPath);
    predictedLabels = predictionData.predicted;

    %% Load surface
    surfacePath = fullfile(surfaceFolder, surfaceFiles(surfaceIdx).name);

    surfaceStruct = load(surfacePath);
    surfaceFields = fieldnames(surfaceStruct);
    surfaceMesh   = surfaceStruct.(surfaceFields{1});

    vertices = surfaceMesh.Vertices * 1000;
    faces    = surfaceMesh.Faces;

    %% Extract predicted vertices
    predictedVertexIdx = find(predictedLabels == 1);

    %% Extract corresponding faces
    predictedFaceMask = any(ismember(faces, predictedVertexIdx), 2);

    %% Store results
    detectedRegions{surfaceIdx}.vertices    = vertices(predictedVertexIdx, :);
    detectedRegions{surfaceIdx}.vertexIdx   = predictedVertexIdx;
    detectedRegions{surfaceIdx}.faces       = faces(predictedFaceMask, :);

end

%% ===================== LOAD AREA STATISTICS =============================

fprintf('Loading area statistics...\n');

areaStats = load(areaStatisticsFile);

%% ====================== PATCH EXTRACTION ================================

fprintf('Running region-growing segmentation...\n');

filteredPatches = cell(numSurfaces, 1);

for surfaceIdx = 1:numSurfaces

    fprintf('Processing surface %d / %d\n', surfaceIdx, numSurfaces);

    %% Area statistics
    totalAreaGT = areaStats.total_area(:, surfaceIdx);

    meanAreaGT = mean(totalAreaGT);
    stdAreaGT  = std(totalAreaGT);

    %% Surface region data
    clusterFaces = detectedRegions{surfaceIdx}.faces;

    numFaces     = size(clusterFaces, 1);
    visitedFaces = false(numFaces, 1);

    patches = {};

    %% ================= REGION GROWING ==================================

    for faceIdx = 1:numFaces

        if visitedFaces(faceIdx)
            continue;
        end

        currentPatch = faceIdx;
        visitedFaces(faceIdx) = true;

        queue = faceIdx;

        while ~isempty(queue)

            currentFace = queue(1);
            queue(1) = [];

            neighboringFaces = find( ...
                any(ismember(clusterFaces, ...
                clusterFaces(currentFace, :)), 2));

            for neighborIdx = neighboringFaces'

                if ~visitedFaces(neighborIdx)

                    visitedFaces(neighborIdx) = true;

                    currentPatch = [currentPatch; neighborIdx];

                    queue = [queue; neighborIdx];

                end
            end
        end

        patches{end + 1} = currentPatch;

    end

    %% ================= PATCH AREA ANALYSIS =============================

    patchAreas = zeros(length(patches), 1);

    for patchIdx = 1:length(patches)

        patchFaceIdx = patches{patchIdx};

        patchFaces = clusterFaces(patchFaceIdx, :);

        surfacePath = fullfile( ...
            surfaceFolder, ...
            surfaceFiles(surfaceIdx).name);

        surfaceStruct = load(surfacePath);
        surfaceFields = fieldnames(surfaceStruct);
        surfaceMesh   = surfaceStruct.(surfaceFields{1});

        vertices = surfaceMesh.Vertices * 1000;

        v1 = vertices(patchFaces(:,1), :);
        v2 = vertices(patchFaces(:,2), :);
        v3 = vertices(patchFaces(:,3), :);

        edge1 = v2 - v1;
        edge2 = v3 - v1;

        crossProduct = cross(edge1, edge2, 2);

        triangleAreas = 0.5 * sqrt(sum(crossProduct.^2, 2));

        patchAreas(patchIdx) = sum(triangleAreas);

    end

    %% ================= PATCH FILTERING ================================

    lowerThreshold = meanAreaGT - 2 * stdAreaGT;
    upperThreshold = meanAreaGT + 2 * stdAreaGT;

    validPatchMask = ...
        patchAreas >= lowerThreshold & ...
        patchAreas <= upperThreshold;

    validPatches = patches(validPatchMask);

    filteredPatches{surfaceIdx} = validPatches;

end

%% ===================== PATCH CENTER EXTRACTION ==========================

fprintf('Extracting patch centers...\n');

patchCenters = cell(numSurfaces, 1);

for surfaceIdx = 1:numSurfaces

    surfacePath = fullfile(surfaceFolder, surfaceFiles(surfaceIdx).name);

    surfaceStruct = load(surfacePath);
    surfaceFields = fieldnames(surfaceStruct);
    surfaceMesh   = surfaceStruct.(surfaceFields{1});

    vertices = surfaceMesh.Vertices * 1000;

    clusterFaces = detectedRegions{surfaceIdx}.faces;

    currentCenters = [];

    for patchIdx = 1:length(filteredPatches{surfaceIdx})

        patchFaceIdx = filteredPatches{surfaceIdx}{patchIdx};

        patchFaces = clusterFaces(patchFaceIdx, :);

        uniqueVertices = unique(patchFaces);

        patchCenter = mean(vertices(uniqueVertices, :));

        currentCenters = [currentCenters; patchCenter];

    end

    patchCenters{surfaceIdx} = currentCenters;

end

%% ===================== SURFACE PROJECTION ===============================

fprintf('Running multi-surface projection...\n');

projectedPoints = [];

for surfaceIdx = 1:numSurfaces

    currentCenters = patchCenters{surfaceIdx};

    currentCenters = currentCenters( ...
        ~any(isnan(currentCenters), 2), :);

    projectedPoints = [projectedPoints; currentCenters];

end

%% ======================= DBSCAN CLUSTERING ==============================

fprintf('Running DBSCAN clustering...\n');

[clusterLabels, corePoints] = dbscan( ...
    projectedPoints, ...
    params.dbscanEpsilon, ...
    params.dbscanMinPts);

clusterCenters = [];
clusterIDs     = unique(clusterLabels);

for clusterIdx = clusterIDs'

    if clusterIdx <= 0
        continue;
    end

    clusterPoints = projectedPoints(clusterLabels == clusterIdx, :);

    clusterCenters = [clusterCenters; mean(clusterPoints, 1)];

end

%% ===================== REMOVE LOWER POINTS ==============================

clusterCenters = clusterCenters( ...
    clusterCenters(:,3) >= params.zThreshold, :);

%% ===================== SURFACE SELECTION ================================

fprintf('Selecting optimal surface...\n');

surfaceDistances = zeros(numSurfaces, 1);

for surfaceIdx = 1:numSurfaces

    surfacePath = fullfile(surfaceFolder, surfaceFiles(surfaceIdx).name);

    surfaceStruct = load(surfacePath);
    surfaceFields = fieldnames(surfaceStruct);
    surfaceMesh   = surfaceStruct.(surfaceFields{1});

    vertices = surfaceMesh.Vertices * 1000;

    [~, distances] = knnsearch(vertices, clusterCenters);

    surfaceDistances(surfaceIdx) = sum(distances);

end

[~, selectedSurfaceIdx] = min(surfaceDistances);

fprintf('Selected surface: %d\n', selectedSurfaceIdx);

%% ===================== PROJECT ONTO SURFACE =============================

surfacePath = fullfile( ...
    surfaceFolder, ...
    surfaceFiles(selectedSurfaceIdx).name);

surfaceStruct = load(surfacePath);
surfaceFields = fieldnames(surfaceStruct);
surfaceMesh   = surfaceStruct.(surfaceFields{1});

surfaceVertices = surfaceMesh.Vertices * 1000;

projectedCenters = zeros(size(clusterCenters));

for pointIdx = 1:size(clusterCenters,1)

    distances = sqrt(sum( ...
        (surfaceVertices - clusterCenters(pointIdx,:)).^2, 2));

    [~, nearestIdx] = min(distances);

    projectedCenters(pointIdx,:) = surfaceVertices(nearestIdx,:);

end

%% ===================== PROJECT GROUND TRUTH =============================

projectedGroundTruth = zeros(size(groundTruth));

for electrodeIdx = 1:size(groundTruth,1)

    distances = sqrt(sum( ...
        (surfaceVertices - groundTruth(electrodeIdx,:)).^2, 2));

    [~, nearestIdx] = min(distances);

    projectedGroundTruth(electrodeIdx,:) = surfaceVertices(nearestIdx,:);

end

%% ========================= EVALUATION ===================================

fprintf('Evaluating detections...\n');

truePositives  = [];
falsePositives = [];
falseNegatives = [];

assignedGT = false(size(projectedGroundTruth,1),1);

for detectionIdx = 1:size(projectedCenters,1)

    [nearestGTIdx, distanceValue] = knnsearch( ...
        projectedGroundTruth, ...
        projectedCenters(detectionIdx,:));

    if distanceValue <= params.falsePositiveThresh

        assignedGT(nearestGTIdx) = true;

        truePositives = [ ...
            truePositives;
            projectedCenters(detectionIdx,:)];

    else

        falsePositives = [ ...
            falsePositives;
            projectedCenters(detectionIdx,:)];

    end
end

falseNegatives = projectedGroundTruth(~assignedGT,:);

%% ========================= RESULTS ======================================

fprintf('\n');
fprintf('================ RESULTS ================\n');
fprintf('Detected Electrodes : %d\n', size(projectedCenters,1));
fprintf('True Positives      : %d\n', size(truePositives,1));
fprintf('False Positives     : %d\n', size(falsePositives,1));
fprintf('False Negatives     : %d\n', size(falseNegatives,1));
fprintf('=========================================\n');

%% ========================= VISUALIZATION ================================

figure;
hold on;
axis equal;
grid on;

scatter3( ...
    truePositives(:,1), ...
    truePositives(:,2), ...
    truePositives(:,3), ...
    60, 'g', 'filled');

scatter3( ...
    falsePositives(:,1), ...
    falsePositives(:,2), ...
    falsePositives(:,3), ...
    60, 'r', 'filled');

scatter3( ...
    falseNegatives(:,1), ...
    falseNegatives(:,2), ...
    falseNegatives(:,3), ...
    60, 'y', 'filled');

xlabel('X');
ylabel('Y');
zlabel('Z');

title('EEG Electrode Localization Results');

view(3);
camlight;