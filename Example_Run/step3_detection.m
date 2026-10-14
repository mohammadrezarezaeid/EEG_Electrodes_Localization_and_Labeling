%% ========================================================================
%  STEP 3 - EEG electrode detection from the classified MR head surfaces
%  ------------------------------------------------------------------------
%  Takes the per-vertex predictions of the trained classifier (Step 2) on
%  the 20 head surfaces of one subject (Step 1), turns them into electrode
%  coordinates, and scores those coordinates against the manual ground truth.
%
%  WHAT THIS SCRIPT DOES
%    Section 1  Load the manual ground truth
%    Section 2  Load the 20 head surfaces
%    Section 3  Load the per-vertex predictions and keep the predicted faces
%    Section 4  Region growing + area gate: group predicted faces into
%               connected patches and keep only electrode-sized patches
%    Section 5  Patch centres: one candidate coordinate per surviving patch
%    Section 6  Pool the candidates of all surfaces, merge them with DBSCAN,
%               and match the detections to the ground truth
%    Section 7  Print the metrics and draw the TP / FP / FN figure
%    Section 8  Save the detections and the selected surface for Step 4
%
%  WHY POOLING AND DBSCAN
%    Each surface is an independent extraction of the same head at a
%    different intensity threshold, so an electrode is usually detected on
%    several surfaces at nearly the same location. Pooling and clustering
%    turn those repeated detections into a single coordinate and suppress
%    isolated responses that appear on only one surface.
%
%  FOLDER LAYOUT (relative to this script; nothing has to be moved)
%    results/step1/   HC023_electrode_position_SCS.mat   ground truth (mm, SCS)
%    results/step1/surfaces/
%                     result_with_surf*.mat              the 20 head surfaces
%                     (mesh struct: Vertices n x 3 in metres, Faces m x 3)
%    results/step2/   HC023_pred.mat                     cell array 'predicted' {20 x 1},
%                     element c = 0/1 label per vertex of surface c, in the
%                     SAME order as dir('result_with_surf*.mat')
%    results/step3/   output: HC023_Detection.mat        'detections' N x 3 (mm, SCS)
%                             selected_surface_HC023.mat 'Vertices' (mm), 'Faces',
%                                                        'selectedSurfaceIdx'
%
%  COORDINATES
%    Meshes are stored in metres and converted to millimetres on load.
%    Ground truth is already in millimetres (SCS). Every distance is in mm.
%
%  HOW TO RUN
%    Whole step : press Run (F5), or  run('step3_detection.m')
%    One part   : run the sections in order with Ctrl+Enter.
%
%  Requires MATLAB R2019a+ and the Statistics and Machine Learning Toolbox
%  (dbscan, knnsearch).
%  Author: Mohammadreza Rezaei-Dastjerdehei
% ========================================================================

%% 0. CONFIGURATION ---------------------------------------------------------
clearvars;
close all;
cfg = struct();

% --- Folders (anchored to this script, so the current folder does not matter)
cfg.root = fileparts(mfilename('fullpath'));
if isempty(cfg.root), cfg.root = pwd; end
cfg.resultsDir = fullfile(cfg.root, 'results');
cfg.step1Dir   = fullfile(cfg.resultsDir, 'step1');
cfg.surfaceDir = fullfile(cfg.step1Dir, 'surfaces');
cfg.step2Dir   = fullfile(cfg.resultsDir, 'step2');
cfg.outDir     = fullfile(cfg.resultsDir, 'step3');

% --- Files
cfg.subjectNum      = 23;
cfg.surfacePattern  = 'result_with_surf*.mat';                                                       % Step 1 output
cfg.predictionFile  = fullfile(cfg.step2Dir, sprintf('HC%03d_pred.mat', cfg.subjectNum));            % Step 2 output
cfg.groundTruthFile = fullfile(cfg.step1Dir, sprintf('HC%03d_electrode_position_SCS.mat', cfg.subjectNum));  % Step 1 output
cfg.detectionFile   = fullfile(cfg.outDir,   sprintf('HC%03d_Detection.mat', cfg.subjectNum));        % -> Step 4
cfg.surfaceOutFile  = fullfile(cfg.outDir,   sprintf('selected_surface_HC%03d.mat', cfg.subjectNum)); % -> Step 4

% --- Area gate (patch area in mm^2, from the training dataset)
%     One mean and one std per surface (column c of the training patch areas).
%     On surface c a patch is kept if
%       areaMean(c) - areaNumStd*areaStd(c) <= area <= areaMean(c) + areaNumStd*areaStd(c)
cfg.areaMean   = [156.37718834235673, 151.47190449190336, 150.06974415703456, 149.15772425334197 ...
                  148.40426069488021, 150.19210855624868, 150.54692633509993, 151.03718665152121 ...
                  150.77003933273971, 151.81375135197362, 152.37009464503942, 151.5576947781245 ...
                  151.98518819084219, 151.10671029848751, 152.59058585881621, 152.01849504285855 ...
                  152.97949472809157, 152.9261206350738, 153.49003349951124, 153.81820028579241];   % mean electrode patch area per surface (mm^2)
cfg.areaStd    = [9.9951013992428379, 10.243307487216994, 11.847724374461915, 13.036305490165322 ...
                  12.807712984172991, 13.326272966458806, 13.215728347820583, 11.959591805558695 ...
                  11.898111454188376, 11.91998428859236, 13.601681992911917, 12.732006265001015 ...
                  12.407463830386352, 11.424053422901656, 12.550386220636067, 11.487756651299692 ...
                  11.393477238452578, 10.480536411213173, 10.024178015315606, 9.3954745283893555];   % std of the electrode patch area per surface (mm^2)
cfg.areaNumStd = 2;

% --- Detection (all from the training dataset)
cfg.dbscanEpsilon       = 8;      % DBSCAN radius, smallest inter-electrode spacing of the cap (mm)
cfg.dbscanMinPts        = 2;      % DBSCAN minimum points (low, since noise is low)
cfg.zThreshold          = -75;    % neck cut (mm, SCS)
cfg.numSurfaces         = 20;     % number of surfaces used

% --- Evaluation
cfg.falsePositiveThresh = 10;     % matching tolerance (mm)
cfg.mainElectrodeCount  = 258;    % rows beyond this are dummy electrodes

% --- Display
cfg.drawFigure = true;            % 3-D scatter of TP / FP / FN

% --- Checks
if numel(cfg.areaMean) < cfg.numSurfaces || numel(cfg.areaStd) < cfg.numSurfaces
    error('cfg.areaMean and cfg.areaStd need one value per surface (%d).', cfg.numSurfaces);
end
if ~exist(cfg.outDir, 'dir'), mkdir(cfg.outDir); end
inputs = {cfg.predictionFile, 'Step 2'; cfg.groundTruthFile, 'Step 1'};
for k = 1:size(inputs, 1)
    if ~isfile(inputs{k,1})
        error('Missing input %s (expected from %s).', inputs{k,1}, inputs{k,2});
    end
end

%% 1. LOAD GROUND TRUTH -----------------------------------------------------
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end

groundTruth = load_first_variable(cfg.groundTruthFile);
groundTruth(cfg.mainElectrodeCount+1:end, :) = [];     % scored set only
numGroundTruth = size(groundTruth, 1);

fprintf('HC%03d: %d ground-truth electrodes\n', cfg.subjectNum, numGroundTruth);

%% 2. LOAD SURFACES ---------------------------------------------------------
if ~exist('groundTruth', 'var'), error('Run Sections 0 and 1 first.'); end

surfaceFiles = dir(fullfile(cfg.surfaceDir, cfg.surfacePattern));
if isempty(surfaceFiles)
    error('No %s found in %s (expected from Step 1).', cfg.surfacePattern, cfg.surfaceDir);
end
numSurfaces = min(cfg.numSurfaces, numel(surfaceFiles));

surfaceVerticesAll = cell(numSurfaces, 1);
surfaceFacesAll    = cell(numSurfaces, 1);

for surfaceIdx = 1:numSurfaces
    surfaceMesh = load_first_variable(fullfile(cfg.surfaceDir, surfaceFiles(surfaceIdx).name));
    surfaceVerticesAll{surfaceIdx} = surfaceMesh.Vertices * 1000;   % metres -> mm
    surfaceFacesAll{surfaceIdx}    = surfaceMesh.Faces;
end

fprintf('%d surfaces loaded\n', numSurfaces);

%% 3. EXTRACT PREDICTED FACES -----------------------------------------------
if ~exist('surfaceVerticesAll', 'var'), error('Run Sections 0 to 2 first.'); end

predictionData = load(cfg.predictionFile);
if ~isfield(predictionData, 'predicted')
    error('%s does not contain the variable ''predicted''.', cfg.predictionFile);
end
predictedAll = predictionData.predicted;
if numel(predictedAll) < numSurfaces
    error('%s holds %d surfaces but %d are needed.', ...
          cfg.predictionFile, numel(predictedAll), numSurfaces);
end

detectedRegions = cell(numSurfaces, 1);

for surfaceIdx = 1:numSurfaces
    predictedLabels = predictedAll{surfaceIdx};
    vertices = surfaceVerticesAll{surfaceIdx};
    faces    = surfaceFacesAll{surfaceIdx};

    % The prediction vector and the mesh must line up vertex for vertex
    if numel(predictedLabels) ~= size(vertices, 1)
        error(['Surface %d: %d predictions but %d vertices. The surface order ' ...
               'in %s does not match dir(''%s'').'], ...
              surfaceIdx, numel(predictedLabels), size(vertices, 1), ...
              cfg.predictionFile, cfg.surfacePattern);
    end

    predictedVertexIdx = find(predictedLabels == 1);
    predictedFaceMask  = any(ismember(faces, predictedVertexIdx), 2);

    detectedRegions{surfaceIdx}.vertices  = vertices(predictedVertexIdx, :);
    detectedRegions{surfaceIdx}.vertexIdx = predictedVertexIdx;
    detectedRegions{surfaceIdx}.faces     = faces(predictedFaceMask, :);

    fprintf('  surface %2d: %6d predicted vertices\n', surfaceIdx, numel(predictedVertexIdx));
end

%% 4. REGION GROWING AND AREA GATE ------------------------------------------
if ~exist('detectedRegions', 'var'), error('Run Sections 0 to 3 first.'); end

filteredPatches = cell(numSurfaces, 1);

for surfaceIdx = 1:numSurfaces
    % Area gate of this surface
    lowerThreshold = cfg.areaMean(surfaceIdx) - cfg.areaNumStd * cfg.areaStd(surfaceIdx);
    upperThreshold = cfg.areaMean(surfaceIdx) + cfg.areaNumStd * cfg.areaStd(surfaceIdx);

    clusterFaces = detectedRegions{surfaceIdx}.faces;
    vertices     = surfaceVerticesAll{surfaceIdx};

    patches    = grow_patches(clusterFaces);
    patchAreas = patch_areas(patches, clusterFaces, vertices);

    validPatchMask = patchAreas >= lowerThreshold & patchAreas <= upperThreshold;
    filteredPatches{surfaceIdx} = patches(validPatchMask);

    fprintf('  surface %2d: %5d patches -> %4d after the area gate (%.2f to %.2f mm^2)\n', ...
            surfaceIdx, numel(patches), numel(filteredPatches{surfaceIdx}), ...
            lowerThreshold, upperThreshold);
end

%% 5. PATCH CENTRES ---------------------------------------------------------
if ~exist('filteredPatches', 'var'), error('Run Sections 0 to 4 first.'); end

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

%% 6. POOLING, DBSCAN AND MATCHING ------------------------------------------
if ~exist('patchCenters', 'var'), error('Run Sections 0 to 5 first.'); end

res   = pool_and_evaluate(1:numSurfaces, patchCenters, surfaceVerticesAll, groundTruth, cfg);
stats = res.stats;

%% 7. RESULTS ---------------------------------------------------------------
if ~exist('res', 'var'), error('Run Sections 0 to 6 first.'); end

fprintf('\n');
fprintf('============= POOLED DETECTION, HC%03d, %d SURFACES =============\n', ...
        cfg.subjectNum, numSurfaces);
fprintf('  pooled patch centres      : %d\n',   size(res.projectedPoints, 1));
fprintf('  DBSCAN clusters kept      : %d\n',   size(res.clusterCenters, 1));
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

if cfg.drawFigure
    figure; hold on; axis equal; grid on;
    scatter3(stats.truePositives(:,1),  stats.truePositives(:,2),  stats.truePositives(:,3),  60, 'g', 'filled');
    scatter3(stats.falsePositives(:,1), stats.falsePositives(:,2), stats.falsePositives(:,3), 60, 'r', 'filled');
    scatter3(stats.falseNegatives(:,1), stats.falseNegatives(:,2), stats.falseNegatives(:,3), 60, 'y', 'filled');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    legend({'True positive', 'False positive', 'False negative'});
    title(sprintf('Electrode localization - HC%03d (%d surfaces, %d mm tolerance)', ...
          cfg.subjectNum, numSurfaces, cfg.falsePositiveThresh));
    view(3); camlight;
end

%% 8. SAVE (inputs of Step 4) -----------------------------------------------
if ~exist('res', 'var'), error('Run Sections 0 to 6 first.'); end

% Detected electrode coordinates, N x 3 (mm, SCS)
detections = res.projectedCenters;
save(cfg.detectionFile, 'detections');
fprintf('\n%d detections saved to %s\n', size(detections, 1), cfg.detectionFile);

% Surface used for matching (Vertices in mm)
selectedSurfaceIdx = res.selectedSurfaceIdx;
Vertices = surfaceVerticesAll{selectedSurfaceIdx};
Faces    = surfaceFacesAll{selectedSurfaceIdx};
save(cfg.surfaceOutFile, 'Vertices', 'Faces', 'selectedSurfaceIdx');
fprintf('Selected surface %d saved to %s\n', selectedSurfaceIdx, cfg.surfaceOutFile);


%% ========================== LOCAL FUNCTIONS ===============================

function data = load_first_variable(filename)
% Return the first variable stored in a .mat file.
    s = load(filename);
    f = fieldnames(s);
    data = s.(f{1});
end

function patches = grow_patches(clusterFaces)
% Region growing: group faces that share a vertex into connected patches.
    numFaces     = size(clusterFaces, 1);
    visitedFaces = false(numFaces, 1);
    patches      = {};

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

            neighboringFaces = find(any(ismember(clusterFaces, clusterFaces(currentFace, :)), 2));

            for neighborIdx = neighboringFaces'
                if ~visitedFaces(neighborIdx)
                    visitedFaces(neighborIdx) = true;
                    currentPatch = [currentPatch; neighborIdx]; %#ok<AGROW>
                    queue        = [queue; neighborIdx];        %#ok<AGROW>
                end
            end
        end

        patches{end + 1} = currentPatch; %#ok<AGROW>
    end
end

function patchAreas = patch_areas(patches, clusterFaces, vertices)
% Total triangle area of each patch (mm^2).
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
end

function res = pool_and_evaluate(surfaceIdxList, patchCenters, surfaceVerticesAll, groundTruth, cfg)
% Pool patch centres over surfaces, cluster with DBSCAN, apply the neck cut,
% pick the surface whose vertices are closest to the clusters, then snap
% both detections and ground truth onto that surface before matching.

    % ---- pool the centres
    projectedPoints = [];
    for surfaceIdx = surfaceIdxList(:)'
        currentCenters = patchCenters{surfaceIdx};
        if isempty(currentCenters)
            continue;
        end
        currentCenters  = currentCenters(~any(isnan(currentCenters), 2), :);
        projectedPoints = [projectedPoints; currentCenters]; %#ok<AGROW>
    end

    if isempty(projectedPoints)
        error('No patch centres after filtering for surfaces %s.', mat2str(surfaceIdxList));
    end

    % ---- DBSCAN
    clusterLabels  = dbscan(projectedPoints, cfg.dbscanEpsilon, cfg.dbscanMinPts);
    clusterCenters = [];
    clusterIDs     = unique(clusterLabels);

    for clusterIdx = clusterIDs'
        if clusterIdx <= 0
            continue;                       % noise
        end
        clusterCenters = [clusterCenters; ...
            mean(projectedPoints(clusterLabels == clusterIdx, :), 1)]; %#ok<AGROW>
    end

    % ---- neck cut
    if ~isempty(clusterCenters)
        clusterCenters = clusterCenters(clusterCenters(:,3) >= cfg.zThreshold, :);
    else
        clusterCenters = zeros(0, 3);
    end

    % ---- surface selection
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

    % ---- project and evaluate
    surfaceVertices      = surfaceVerticesAll{selectedSurfaceIdx};
    projectedCenters     = project_onto_surface(clusterCenters, surfaceVertices);
    projectedGroundTruth = project_onto_surface(groundTruth,    surfaceVertices);

    stats = evaluate_detections(projectedCenters, projectedGroundTruth, cfg.falsePositiveThresh);

    % ---- pack
    res.surfaceIdxList       = surfaceIdxList;
    res.projectedPoints      = projectedPoints;
    res.clusterLabels        = clusterLabels;
    res.clusterCenters       = clusterCenters;
    res.selectedSurfaceIdx   = selectedSurfaceIdx;
    res.projectedCenters     = projectedCenters;
    res.projectedGroundTruth = projectedGroundTruth;
    res.stats                = stats;
end

function projected = project_onto_surface(points, surfaceVertices)
% Snap each point to its nearest mesh vertex.
    if isempty(points)
        projected = zeros(0, 3);
        return;
    end
    nearestIdx = knnsearch(surfaceVertices, points);
    projected  = surfaceVertices(nearestIdx, :);
end

function stats = evaluate_detections(detections, projectedGroundTruth, thresh)
% A detection is a true positive when its nearest ground-truth electrode
% is within THRESH (mm).
    numGroundTruth = size(projectedGroundTruth, 1);
    numDetections  = size(detections, 1);

    truePositives  = zeros(0, 3);
    falsePositives = zeros(0, 3);
    matchDistances = zeros(0, 1);

    assignedGT     = false(numGroundTruth, 1);
    isTruePositive = false(numDetections, 1);

    for detectionIdx = 1:numDetections
        [nearestGTIdx, distanceValue] = knnsearch(projectedGroundTruth, detections(detectionIdx, :));

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