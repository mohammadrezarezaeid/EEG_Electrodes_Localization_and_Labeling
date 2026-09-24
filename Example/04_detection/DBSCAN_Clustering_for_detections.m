%% ========================================================================
%  EEG ELECTRODE LOCALIZATION FROM MR HEAD SURFACES -- SINGLE SUBJECT
%  ------------------------------------------------------------------------
%  Example script: takes the per-vertex predictions of the trained
%  classifiers on one subject (HC023) and turns them into electrode
%  coordinates, then scores those coordinates against the manual ground
%  truth.
%
%
%  STEPS IMPLEMENTED HERE
%  ----------------------
%    1  Load the manual ground truth
%    2  Load the 20 head surfaces
%    3  Load the per-vertex predictions and keep the predicted faces
%    4  Region growing: group the predicted faces into connected patches
%    5  Area gate: discard patches whose area is not electrode-sized
%    6  Patch centres: one candidate coordinate per surviving patch
%    7  Pool the candidates of all 20 surfaces
%    8  DBSCAN: merge candidates that recur across surfaces into one detection
%    9  Match the detections to the ground truth and report the metrics
%   10  Save
%
%  WHY STEPS 7-8 EXIST
%  -------------------
%  Each of the 20 surfaces is an independent extraction of the same head at
%  a different intensity threshold, so an electrode is usually detected on
%  several of them at nearly the same location. Pooling and clustering turn
%  those repeated detections into a single coordinate and suppress isolated
%  responses that appear on only one surface.
%
%  INPUT FILES
%  -----------
%    <surfaceFolder>/result_with_surf*.mat
%        one file per surface, each holding a mesh struct with fields
%        Vertices (n x 3, metres) and Faces (m x 3)
%    HC023_pred.mat
%        cell array 'predicted' {20 x 1}; element c is an n_c x 1 vector of
%        0/1 labels for surface c, in the SAME order as the dir() listing
%        of result_with_surf*.mat
%    HC023_electrode_position_SCS.mat
%        ground-truth electrode coordinates (mm, SCS), one row per electrode
%    total_area_training.mat
%        variable 'total_area': reference patch areas from the training set,
%        one column per surface index
%
%  OUTPUT
%  ------
%    printed summary, resultsTable, and detection_results_HC023.mat and
%    selected surface (selected_surface_HC023.mat)
%
%  COORDINATE CONVENTION
%  ---------------------
%  Meshes are stored in metres and converted to millimetres on load. Ground
%  truth is already in millimetres (SCS). Every distance below is in mm.
%  ========================================================================
 
clearvars;
close all;

%% ========================= PARAMETERS ===================================
 
params.dbscanEpsilon       = 8;     % DBSCAN neighbourhood radius from training dataset based on smallest inter-electrode spacing of the cap (mm)
params.dbscanMinPts        = 2;     % DBSCAN parameter from training dataset (Chosen low due to low noise)
params.falsePositiveThresh = 10;    % matching tolerance (mm)
params.zThreshold          = -75;   % neck cut from training dataset (mm, SCS)
params.mainElectrodeCount  = 258;   % rows beyond this are the extra electrodes (dummy electrodes)
params.numSurfaces         = 20;    % #surfaces used
 
params.drawFigure = true;           % 3D scatter of TP / FP / FN

%% =========================== PATHS ======================================
 
subjectNum = 23;

 % Surface loading (20 surfaces)
surfaceFolder   = fullfile('Dataset_surface_Extracted_Hist_match', sprintf('HC%03d', subjectNum));

% It must contain the cell array 'predicted' {20x1}, one 0/1 column per
% surface, in the SAME surface order as dir('result_with_surf*.mat').
predictionFile  = sprintf('HC%03d_pred', subjectNum);

% Folder holding HC%03d_electrode_position_SCS.mat. 
groundTruthFile = sprintf('HC%03d_electrode_position_SCS.mat', subjectNum);

% Area prior. A single fixed reference patch size derived from training dataset is
% used as the patch-area gate for every subject. 
areaStatisticsFile = 'total_area_training.mat';


%% ====================== LOAD GROUND TRUTH ===============================
 
gtStruct    = load(groundTruthFile);
gtFields    = fieldnames(gtStruct);
groundTruth = gtStruct.(gtFields{1});
 
groundTruth(params.mainElectrodeCount+1:end, :) = [];     % scored set only
numGroundTruth = size(groundTruth, 1);
 
fprintf('HC%03d: %d ground-truth electrodes\n', subjectNum, numGroundTruth);
 
%% ========================= LOAD SURFACES ================================
 
surfaceFiles = dir(fullfile(surfaceFolder, 'result_with_surf*.mat'));
numSurfaces  = min(params.numSurfaces, numel(surfaceFiles));

if numel(surfaceFiles) == 0
    error('No result_with_surf*.mat found in %s', surfaceFolder);
end

surfaceVerticesAll = cell(numSurfaces, 1);
surfaceFacesAll    = cell(numSurfaces, 1);
 
for surfaceIdx = 1:numSurfaces
 
    surfaceStruct = load(fullfile(surfaceFolder, surfaceFiles(surfaceIdx).name));
    surfaceFields = fieldnames(surfaceStruct);
    surfaceMesh   = surfaceStruct.(surfaceFields{1});
 
    surfaceVerticesAll{surfaceIdx} = surfaceMesh.Vertices * 1000;
    surfaceFacesAll{surfaceIdx}    = surfaceMesh.Faces;
 
end
 
fprintf('%d surfaces loaded\n', numSurfaces);


%% ==================== EXTRACT PREDICTED PATCHES =========================
 
predictionData = load(predictionFile);
 
if ~isfield(predictionData, 'predicted')
    error('%s does not contain the variable ''predicted''.', predictionFile);
end
 
predictedAll = predictionData.predicted;
 
if numel(predictedAll) < numSurfaces
    error('%s holds %d surfaces but %d are needed.', ...
        predictionFile, numel(predictedAll), numSurfaces);
end
 
detectedRegions = cell(numSurfaces, 1);
 
for surfaceIdx = 1:numSurfaces
 
    predictedLabels = predictedAll{surfaceIdx};
 
    vertices = surfaceVerticesAll{surfaceIdx};
    faces    = surfaceFacesAll{surfaceIdx};
 
    % The prediction vector and the mesh must line up vertex for vertex.
    if numel(predictedLabels) ~= size(vertices, 1)
        error(['Surface %d: %d predictions but %d vertices. The surface order ' ...
               'in %s does not match dir(''result_with_surf*.mat'').'], ...
            surfaceIdx, numel(predictedLabels), size(vertices,1), predictionFile);
    end
 
    predictedVertexIdx = find(predictedLabels == 1);
 
    predictedFaceMask = any(ismember(faces, predictedVertexIdx), 2);
 
    detectedRegions{surfaceIdx}.vertices  = vertices(predictedVertexIdx, :);
    detectedRegions{surfaceIdx}.vertexIdx = predictedVertexIdx;
    detectedRegions{surfaceIdx}.faces     = faces(predictedFaceMask, :);
 
    fprintf('  surface %2d: %6d predicted vertices\n', ...
        surfaceIdx, numel(predictedVertexIdx));
 
end

%% ===================== LOAD AREA STATISTICS =============================
 
areaStats = load(areaStatisticsFile);
 
if size(areaStats.total_area, 2) < numSurfaces
    error('%s has %d columns but %d surfaces are used.', ...
        areaStatisticsFile, size(areaStats.total_area,2), numSurfaces);
end
 
%% ================ REGION GROWING AND PATCH FILTERING ====================
 
filteredPatches = cell(numSurfaces, 1);
 
for surfaceIdx = 1:numSurfaces
 
    totalAreaGT = areaStats.total_area(:, surfaceIdx);
 
    meanAreaGT = mean(totalAreaGT);
    stdAreaGT  = std(totalAreaGT);
 
    clusterFaces = detectedRegions{surfaceIdx}.faces;
    vertices     = surfaceVerticesAll{surfaceIdx};
 
    numFaces     = size(clusterFaces, 1);
    visitedFaces = false(numFaces, 1);
 
    patches = {};
 
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
                any(ismember(clusterFaces, clusterFaces(currentFace, :)), 2));
 
            for neighborIdx = neighboringFaces'
 
                if ~visitedFaces(neighborIdx)
 
                    visitedFaces(neighborIdx) = true;
 
                    currentPatch = [currentPatch; neighborIdx]; %#ok<AGROW>
 
                    queue = [queue; neighborIdx]; %#ok<AGROW>
 
                end
            end
        end
 
        patches{end + 1} = currentPatch; %#ok<AGROW>
 
    end
 
    % ---- patch areas ----
    patchAreas = zeros(length(patches), 1);
 
    for patchIdx = 1:length(patches)
 
        patchFaces = clusterFaces(patches{patchIdx}, :);
 
        v1 = vertices(patchFaces(:,1), :);
        v2 = vertices(patchFaces(:,2), :);
        v3 = vertices(patchFaces(:,3), :);
 
        crossProduct  = cross(v2 - v1, v3 - v1, 2);
        triangleAreas = 0.5 * sqrt(sum(crossProduct.^2, 2));
 
        patchAreas(patchIdx) = sum(triangleAreas);
 
    end
 
    % ---- area gate ----
    lowerThreshold = meanAreaGT - 2 * stdAreaGT;
    upperThreshold = meanAreaGT + 2 * stdAreaGT;
 
    validPatchMask = patchAreas >= lowerThreshold & patchAreas <= upperThreshold;
 
    filteredPatches{surfaceIdx} = patches(validPatchMask);
 
    fprintf('  surface %2d: %5d patches -> %4d after the area gate\n', ...
        surfaceIdx, numel(patches), numel(filteredPatches{surfaceIdx}));
 
end

%% ===================== PATCH CENTER EXTRACTION ==========================
 
patchCenters = cell(numSurfaces, 1);
 
for surfaceIdx = 1:numSurfaces
 
    vertices     = surfaceVerticesAll{surfaceIdx};
    clusterFaces = detectedRegions{surfaceIdx}.faces;
 
    currentCenters = [];
 
    for patchIdx = 1:length(filteredPatches{surfaceIdx})
 
        patchFaces     = clusterFaces(filteredPatches{surfaceIdx}{patchIdx}, :);
        uniqueVertices = unique(patchFaces);
 
        currentCenters = [currentCenters; mean(vertices(uniqueVertices, :))]; %#ok<AGROW>
 
    end
 
    patchCenters{surfaceIdx} = currentCenters;
 
end
%% =============== POOLING, DBSCAN AND EVALUATION =========================
 
res = poolAndEvaluate(1:numSurfaces, patchCenters, surfaceVerticesAll, ...
                      groundTruth, params);
 
stats = res.stats;
 
%% ============================ RESULTS ===================================
 
fprintf('\n');
fprintf('============= POOLED DETECTION, HC%03d, %d SURFACES =============\n', ...
    subjectNum, numSurfaces);
fprintf('  pooled patch centres      : %d\n',   size(res.projectedPoints,1));
fprintf('  DBSCAN clusters kept      : %d\n',   size(res.clusterCenters,1));
fprintf('  surface used for matching : %d\n',   res.selectedSurfaceIdx);
fprintf('  ----------------------------------------------------\n');
fprintf('  detections                : %d\n',   stats.nDetections);
fprintf('  true positives            : %d\n',   stats.nTruePositives);
fprintf('  false positives           : %d\n',   stats.nFalsePositives);
fprintf('  matched electrodes        : %d / %d\n', stats.nMatchedGT, numGroundTruth);
fprintf('  false negatives           : %d\n',   stats.nFalseNegatives);
fprintf('  ----------------------------------------------------\n');
fprintf('  precision                 : %.4f\n', stats.precision);
fprintf('  recall (detection rate)   : %.4f\n', stats.recall);
fprintf('  F1                        : %.4f\n', stats.f1);
fprintf('  localization error (mm)   : %.2f +- %.2f\n', stats.meanError, stats.stdError);
fprintf('================================================================\n');
 
resultsTable = table(stats.nDetections, stats.nTruePositives, ...
    stats.nFalsePositives, stats.nFalseNegatives, stats.precision, ...
    stats.recall, stats.f1, stats.meanError, stats.stdError, ...
    'VariableNames', {'nDetections','TP','FP','FN','Precision','Recall','F1', ...
                      'ErrorMean','ErrorSD'});
disp(resultsTable);

%% ============================ FIGURE ====================================
 
if params.drawFigure
 
    figure; hold on; axis equal; grid on;
    scatter3(stats.truePositives(:,1),  stats.truePositives(:,2),  stats.truePositives(:,3),  60, 'g', 'filled');
    scatter3(stats.falsePositives(:,1), stats.falsePositives(:,2), stats.falsePositives(:,3), 60, 'r', 'filled');
    scatter3(stats.falseNegatives(:,1), stats.falseNegatives(:,2), stats.falseNegatives(:,3), 60, 'y', 'filled');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    legend({'True positive','False positive','False negative'});
    title(sprintf('Electrode localization - HC%03d (%d surfaces, %d mm tolerance)', ...
        subjectNum, numSurfaces, params.falsePositiveThresh));
    view(3); camlight;
 
end
 
%% ============================ SAVE ==================================
%  Output of the detection stage: N x 3 detected electrode coordinates
%  (mm, SCS).

detections = res.projectedCenters;

save(sprintf('HC%03d_Detection.mat', subjectNum), 'detections');

fprintf('\n%d detections saved to detection_results_HC%03d.mat\n', ...
    size(detections,1), subjectNum);


selectedSurfaceIdx = res.selectedSurfaceIdx;
Vertices    = surfaceVerticesAll{selectedSurfaceIdx};
Faces       = surfaceFacesAll{selectedSurfaceIdx};

save(sprintf('selected_surface_HC%03d.mat', subjectNum), ...
    'Vertices', 'Faces', 'selectedSurfaceIdx');

fprintf('selected surface %d saved to selected_surface_HC%03d.mat\n', ...
    selectedSurfaceIdx, subjectNum)

%% ========================= LOCAL FUNCTIONS ==============================
 
function res = poolAndEvaluate(surfaceIdxList, patchCenters, surfaceVerticesAll, ...
    groundTruth, params)
%POOLANDEVALUATE Pool patch centres over surfaces, cluster with DBSCAN, score.
%   Same code path as the batch version: concatenate the centres, drop NaN
%   rows, DBSCAN, take cluster means, apply the neck cut, pick the surface
%   whose vertices are closest to the clusters, then snap both detections
%   and ground truth onto that surface before matching.
 
    %% ---------------------- pool the centres ---------------------------
    projectedPoints = [];
 
    for surfaceIdx = surfaceIdxList(:)'
 
        currentCenters = patchCenters{surfaceIdx};
 
        if isempty(currentCenters)
            continue;
        end
 
        currentCenters = currentCenters(~any(isnan(currentCenters), 2), :);
 
        projectedPoints = [projectedPoints; currentCenters]; %#ok<AGROW>
 
    end
 
    if isempty(projectedPoints)
        error('No patch centres after filtering for surfaces %s.', mat2str(surfaceIdxList));
    end
 
    %% ------------------------- DBSCAN ----------------------------------
    clusterLabels = dbscan(projectedPoints, params.dbscanEpsilon, params.dbscanMinPts);
 
    clusterCenters = [];
    clusterIDs     = unique(clusterLabels);
 
    for clusterIdx = clusterIDs'
 
        if clusterIdx <= 0
            continue;                       % noise
        end
 
        clusterCenters = [clusterCenters; ...
            mean(projectedPoints(clusterLabels == clusterIdx, :), 1)]; %#ok<AGROW>
 
    end
 
    %% ------------------------ neck cut ---------------------------------
    if ~isempty(clusterCenters)
        clusterCenters = clusterCenters(clusterCenters(:,3) >= params.zThreshold, :);
    else
        clusterCenters = zeros(0,3);
    end
 
    %% --------------------- surface selection ---------------------------
    surfaceDistances = inf(numel(surfaceIdxList), 1);
 
    for ii = 1:numel(surfaceIdxList)
 
        if isempty(clusterCenters)
            continue;
        end
 
        [~, distances] = knnsearch(surfaceVerticesAll{surfaceIdxList(ii)}, clusterCenters);
 
        surfaceDistances(ii) = sum(distances);
 
    end
 
    [~, bestLocal]     = min(surfaceDistances);
    selectedSurfaceIdx = surfaceIdxList(bestLocal);
 
    %% ------------------- project and evaluate --------------------------
    surfaceVertices = surfaceVerticesAll{selectedSurfaceIdx};
 
    projectedCenters     = projectOntoSurface(clusterCenters, surfaceVertices);
    projectedGroundTruth = projectOntoSurface(groundTruth,    surfaceVertices);
 
    stats = evaluateDetections(projectedCenters, projectedGroundTruth, ...
        params.falsePositiveThresh);
 
    %% ---------------------------- pack ---------------------------------
    res.surfaceIdxList       = surfaceIdxList;
    res.projectedPoints      = projectedPoints;
    res.clusterLabels        = clusterLabels;
    res.clusterCenters       = clusterCenters;
    res.selectedSurfaceIdx   = selectedSurfaceIdx;
    res.projectedCenters     = projectedCenters;
    res.projectedGroundTruth = projectedGroundTruth;
    res.stats                = stats;
 
end
 
 
function projected = projectOntoSurface(points, surfaceVertices)
%PROJECTONTOSURFACE Snap each point to its nearest mesh vertex.
 
    if isempty(points)
        projected = zeros(0, 3);
        return;
    end
 
    nearestIdx = knnsearch(surfaceVertices, points);
    projected  = surfaceVertices(nearestIdx, :);
 
end
 
 
function stats = evaluateDetections(detections, projectedGroundTruth, thresh)
%EVALUATEDETECTIONS Score detections against ground truth.
%   A detection is a true positive when its nearest ground-truth electrode
%   is within THRESH.
 
    numGroundTruth = size(projectedGroundTruth, 1);
    numDetections  = size(detections, 1);
 
    truePositives  = zeros(0, 3);
    falsePositives = zeros(0, 3);
    matchDistances = zeros(0, 1);
 
    assignedGT     = false(numGroundTruth, 1);
    isTruePositive = false(numDetections, 1);
 
    for detectionIdx = 1:numDetections
 
        [nearestGTIdx, distanceValue] = knnsearch( ...
            projectedGroundTruth, detections(detectionIdx, :));
 
        if distanceValue <= thresh
 
            assignedGT(nearestGTIdx)     = true;
            isTruePositive(detectionIdx) = true;
 
            truePositives  = [truePositives;  detections(detectionIdx, :)]; %#ok<AGROW>
            matchDistances = [matchDistances; distanceValue];               %#ok<AGROW>
 
        else
 
            falsePositives = [falsePositives; detections(detectionIdx, :)]; %#ok<AGROW>
 
        end
    end
 
    falseNegatives = projectedGroundTruth(~assignedGT, :);
 
    stats.assignedGT      = assignedGT;
    stats.isTruePositive  = isTruePositive;
    stats.nDetections     = numDetections;
    stats.nTruePositives  = size(truePositives, 1);
    stats.nFalsePositives = size(falsePositives, 1);
    stats.nMatchedGT      = sum(assignedGT);
    stats.nFalseNegatives = size(falseNegatives, 1);
 
    stats.truePositives  = truePositives;
    stats.falsePositives = falsePositives;
    stats.falseNegatives = falseNegatives;
    stats.matchDistances = matchDistances;
 
    if numDetections > 0
        stats.precision = stats.nTruePositives / numDetections;
    else
        stats.precision = 0;
    end
 
    if numGroundTruth > 0
        stats.recall = stats.nMatchedGT / numGroundTruth;
    else
        stats.recall = 0;
    end
 
    if (stats.precision + stats.recall) > 0
        stats.f1 = 2 * stats.precision * stats.recall / (stats.precision + stats.recall);
    else
        stats.f1 = 0;
    end
 
    if isempty(matchDistances)
        stats.meanError = NaN;
        stats.stdError  = NaN;
    else
        stats.meanError = mean(matchDistances);
        stats.stdError  = std(matchDistances);
    end
 
end