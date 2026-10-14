%% ========================================================================
%  STEP 1 - Head surfaces, ground-truth labels and curvature features
%  ------------------------------------------------------------------------
%  Starts from one T1-weighted MRI (NIfTI) and produces everything the
%  classifier in Step 2 needs:
%
%    Section 1  Start Brainstorm and select a dedicated protocol
%    Section 2  Import the MRI and MNI-normalize it (SPM 'maff8'). This also
%               defines the fiducials (NAS/LPA/RPA) used by the SCS frame.
%    Section 3  Head-surface extraction: sweep the binarization threshold
%               for background (bgLevel) to white-matter (whiteLevel) 
%               (extracted from training datasets steps) and build one
%               closed head surface per threshold (SCS, metres).
%    Section 4  Ground truth MNI -> SCS: map the digitised electrode
%               positions into the SCS frame of the surfaces.
%    Section 5  Ground-truth mesh labels: on every surface, mark the vertices
%               within electrodeRadius of each electrode as "electrode".
%    Section 6  Curvature features: 110 shape descriptors per vertex of every
%               surface (10 per-vertex features + their mean and std over
%               5 neighbourhood radii).
%
%  WHY SEVERAL SURFACES
%    Each threshold gives a slightly different extraction of the same head,
%    so an electrode is visible on several of them. Step 3 pools the
%    detections over all surfaces.
%
%  FOLDER LAYOUT (relative to this script; nothing has to be moved)
%    data/                 HC023_with_mni_restore.nii.gz      T1 MRI
%                          HC023_electrode_position.xlsx      ground truth (MNI)
%    results/step1/surfaces/
%                          result_with_surfNNN.mat            one surface per threshold
%                                                             (sHead: Vertices in SCS metres, Faces)
%    results/step1/        HC023_mri_normalized.mat           normalized Brainstorm MRI
%                          HC023_electrode_position_SCS.mat   posSCS : ground truth in SCS (mm)
%                          Transformation2SCS_HC023.mat       transform : 4 x 4 MNI -> SCS
%                          HC023_mesh_gt.mat                  Label_vertices {nSurfaces x 1}
%                          HC023_features_vertices.mat        features_vertices {nSurfaces x 1},
%                                                             each [nVertices x 110]
%
%  FEATURE COLUMNS (features_vertices{i}, one row per vertex of surface i)
%    1 - 10   per-vertex: k1, k2, |k1|, |k2|, K, H, |K|, |H|, shape index, curvedness
%   11 - 30   mean and std of cols 1-10 within  6 mm
%   31 - 50   mean and std within  8 mm
%   51 - 70   mean and std within 10 mm
%   71 - 90   mean and std within 12 mm
%   91 -110   mean and std within 15 mm
%
%  HOW TO RUN
%    Whole step : press Run (F5), or  run('step1_feature_extraction.m')
%    One part   : run Section 0, then any section with Ctrl+Enter. Sections
%                 3 to 6 read their inputs from results/step1/, so after a
%                 crash you can restart from the section that failed.
%
%  REQUIREMENTS
%    - MATLAB (tested with R2023)
%    - Brainstorm on the MATLAB path, with a database folder configured
%      (run 'brainstorm' once interactively if you have never used it),
%      and the SPM12 plugin of Brainstorm for the MNI normalization
%    - GetCurvatures.m (Itzik Ben Shabat, "Curvature Estimation On Triangle
%      Mesh", MATLAB Add-Ons) on the MATLAB path
%
%  Author: Mohammadreza Rezaei-Dastjerdehei
% ========================================================================

%% 0. CONFIGURATION ---------------------------------------------------------
clearvars;
close all;
cfg = struct();

% --- Folders (anchored to this script, so the current folder does not matter)
cfg.root = fileparts(mfilename('fullpath'));
if isempty(cfg.root), cfg.root = pwd; end
cfg.dataDir    = fullfile(cfg.root, 'data');
cfg.outDir     = fullfile(cfg.root, 'results', 'step1');
cfg.surfaceDir = fullfile(cfg.outDir, 'surfaces');

% --- Files
cfg.subjectNum   = 23;
cfg.subjectName  = sprintf('HC%03d', cfg.subjectNum);
cfg.mriFile      = fullfile(cfg.dataDir, sprintf('%s_with_mni_restore.nii.gz', cfg.subjectName));
cfg.gtMniFile    = fullfile(cfg.dataDir, sprintf('%s_electrode_position.xlsx', cfg.subjectName));
cfg.mriNormFile  = fullfile(cfg.outDir,  sprintf('%s_mri_normalized.mat', cfg.subjectName));
cfg.gtScsFile    = fullfile(cfg.outDir,  sprintf('%s_electrode_position_SCS.mat', cfg.subjectName));
cfg.transFile    = fullfile(cfg.outDir,  sprintf('Transformation2SCS_%s.mat', cfg.subjectName));
cfg.labelFile    = fullfile(cfg.outDir,  sprintf('%s_mesh_gt.mat', cfg.subjectName));
cfg.featureFile  = fullfile(cfg.outDir,  sprintf('%s_features_vertices.mat', cfg.subjectName));
cfg.surfacePattern = 'result_with_surf*.mat';

% --- Brainstorm
cfg.protocolName = 'SurfaceExtractionExample';   % dedicated protocol, never touches the user's data

% --- Surface extraction
cfg.bgLevel     = 75.4007;    % lowest threshold: air/background level from the training dataset
cfg.whiteLevel  = 841.6250;   % highest threshold: white-matter level from the training dataset
cfg.nLevels     = 20;         % number of thresholds between the two levels
cfg.nVertices   = 500000;     % max vertices of the final surface
cfg.erodeFactor = 0;          % morphological opening radius (0 = off)
cfg.fillFactor  = 2;          % hole-filling strength passed to tess_fillholes

% --- Ground-truth labels
cfg.electrodeRadius = 6;      % radius (mm) of the patch labeled around each electrode

% --- Features
cfg.featureRadii = [6, 8, 10, 12, 15];   % neighbourhood radii (mm)

% --- Folders and input checks
if ~exist(cfg.surfaceDir, 'dir'), mkdir(cfg.surfaceDir); end   % also creates results/step1/
inputs = {cfg.mriFile; cfg.gtMniFile};
for k = 1:numel(inputs)
    if ~isfile(inputs{k})
        error('Missing input %s (expected in the example data folder).', inputs{k});
    end
end

%% 1. START BRAINSTORM AND SELECT A DEDICATED PROTOCOL ----------------------
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end

brainstorm

iProtocol = bst_get('Protocol', cfg.protocolName);
if isempty(iProtocol)
    gui_brainstorm('CreateProtocol', cfg.protocolName, 0, 0);   % no default anatomy/channels
else
    gui_brainstorm('SetCurrentProtocol', iProtocol);
end

%% 2. IMPORT MRI AND MNI-NORMALIZE ------------------------------------------
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end

sMri = mni_normalization_brainstorm_EX(cfg.subjectName, cfg.mriFile, cfg.mriNormFile);
fprintf('Normalized MRI saved to %s\n', cfg.mriNormFile);

%% 3. EXTRACT ONE HEAD SURFACE PER THRESHOLD --------------------------------
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end
if ~exist('sMri', 'var')
    if ~isfile(cfg.mriNormFile), error('Run Sections 1 and 2 first.'); end
    sMri = load(cfg.mriNormFile);
end

surfaceLevels = linspace(cfg.bgLevel, cfg.whiteLevel, cfg.nLevels);

for level = surfaceLevels
    tic;
    sHead = headsurfext_EX(sMri, cfg.nVertices, cfg.erodeFactor, cfg.fillFactor, level);
    save(fullfile(cfg.surfaceDir, sprintf('result_with_surf%03d.mat', round(level))), 'sHead');
    fprintf('  threshold %7.2f: %d vertices (%.1f s)\n', level, size(sHead.Vertices, 1), toc);
end

fprintf('%d surfaces saved in %s\n', cfg.nLevels, cfg.surfaceDir);

%% 4. GROUND TRUTH: MNI -> SCS ----------------------------------------------
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end
if ~isfile(cfg.mriNormFile), error('Run Sections 1 and 2 first.'); end

% posSCS    : ground truth electrode positions expressed in SCS
% transform : the transformation applied, kept so that the same mapping
%             can be reused or inverted without recomputing it
[posSCS, transform] = Transfom2SCS(cfg.mriNormFile, cfg.gtMniFile);

save(cfg.gtScsFile, 'posSCS');
save(cfg.transFile, 'transform');
fprintf('%d ground-truth electrodes saved in SCS to %s\n', size(posSCS, 1), cfg.gtScsFile);

%% 5. GROUND-TRUTH LABELS ON EVERY SURFACE ----------------------------------
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end
if ~isfile(cfg.gtScsFile), error('Run Section 4 first.'); end

fileList = surface_file_list(cfg);
Position_countour_electrodes = load_first_variable(cfg.gtScsFile);   % [nElectrodes x 3], SCS mm

tic
Label_vertices = label_mesh_gt(fileList, cfg.surfaceDir, Position_countour_electrodes, ...
                               cfg.electrodeRadius);
save(cfg.labelFile, 'Label_vertices');
fprintf('Ground-truth labels of %d surfaces saved to %s (%.1f s)\n', ...
        numel(fileList), cfg.labelFile, toc);

%% 6. CURVATURE FEATURES ----------------------------------------------------
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end

fileList = surface_file_list(cfg);

tic
[features_vertices, err_vertices] = extract_features(fileList, cfg.surfaceDir, ...
                                                     cfg.featureRadii, cfg.nLevels);
save(cfg.featureFile, 'features_vertices');
fprintf('Features of %d surfaces saved to %s (%.1f s)\n', numel(fileList), cfg.featureFile, toc);


%% ========================== LOCAL FUNCTIONS ===============================

% --------------------------------------------------------------- utilities
function data = load_first_variable(filename)
% Return the first variable stored in a .mat file.
    s = load(filename);
    f = fieldnames(s);
    data = s.(f{1});
end

function fileList = surface_file_list(cfg)
% Surface files of Section 3. dir() returns them in alphabetical order, which
% for the zero-padded "%03d" names is also the order of increasing threshold.
    fileList = dir(fullfile(cfg.surfaceDir, cfg.surfacePattern));
    if isempty(fileList)
        error('No %s found in %s. Run Section 3 first.', cfg.surfacePattern, cfg.surfaceDir);
    end
    if numel(fileList) ~= cfg.nLevels
        warning(['%d surface files found in %s but cfg.nLevels = %d. ' ...
                 'Delete old surfaces from a previous run.'], ...
                numel(fileList), cfg.surfaceDir, cfg.nLevels);
    end
end

% ------------------------------------------------- MRI import + normalization
function sMri = mni_normalization_brainstorm_EX(subjectName, mriFilePath, outFilePath)
% Import a NIfTI MRI into Brainstorm and MNI-normalize it.
%   Brainstorm must already be running with a protocol selected (Section 1).
%   subjectName  Name of the subject in the Brainstorm database
%   mriFilePath  Full path to the input NIfTI file (.nii / .nii.gz)
%   outFilePath  Full path of the .mat FILE where the normalized MRI is saved
%   sMri         Brainstorm MRI structure with the MNI transformation and
%                fiducials (SCS: NAS/LPA/RPA) defined
    if nargin < 3
        error('Three inputs are required: subjectName, mriFilePath and outFilePath');
    end

    % Start a new report
    sFiles = [];
    bst_report('Start', sFiles);

    % Process: Import MRI
    sFiles = bst_process('CallProcess', 'process_import_mri', sFiles, [], ...
        'subjectname', subjectName, ...
        'mrifile',     {mriFilePath, 'Nifti1'}, ...
        'nas',         [0, 0, 0], ...
        'lpa',         [0, 0, 0], ...
        'rpa',         [0, 0, 0], ...
        'ac',          [0, 0, 0], ...
        'pc',          [0, 0, 0], ...
        'ih',          [0, 0, 0]);

    % Process: MNI normalization
    sFiles = bst_process('CallProcess', 'process_mni_normalize', sFiles, [], ...
        'subjectname', subjectName, ...
        'method',      'maff8', ...  % Affine registration using SPM mutual information algorithm
        'uset2',       0);

    % Load the normalized MRI structure and save it to the user-defined path
    ProtocolInfo = bst_get('ProtocolInfo');
    if isempty(ProtocolInfo)
        gui_brainstorm('CreateProtocol', 'MyProtocol', 0, 0);
    end
    sSubject = bst_get('Subject', subjectName);
    sMri     = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    outDir   = bst_fileparts(outFilePath);
    if ~isempty(outDir) && ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    bst_save(outFilePath, sMri, 'v7');

    % Save and display report
    ReportFile = bst_report('Save', sFiles);
    bst_report('Open', ReportFile);
end

% ---------------------------------------------------------- surface extraction
function [sHead] = headsurfext_EX(sMri, nVertices, erodeFactor, fillFactor, bgLevel)
% Extract a closed head surface from an MRI at one intensity threshold.
%   Adapted from Brainstorm's tess_isohead.m. Unlike the original, the
%   binarization threshold is an input, so it can be swept over a range.
%   sMri        Brainstorm MRI structure. Fiducials (SCS) must be defined.
%   nVertices   Maximum number of vertices in the output surface.
%   erodeFactor Radius (voxels) of the morphological opening used to
%               remove small components. 0 turns it off.
%   fillFactor  Hole-filling parameter passed to tess_fillholes.
%   bgLevel     Intensity threshold. Voxels above it count as head.
%               Optional: defaults to sMri.Histogram.bgLevel.
%   sHead       .Vertices [Nv x 3] in SCS coordinates (metres), .Faces [Nf x 3]

    % ===== Input checks =====
    if ~isfield(sMri, 'Histogram') || isempty(sMri.Histogram) || isempty(sMri.SCS) || ...
            isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
        error('You need to set the fiducial points in the MRI first.');
    end
    if nargin < 5 || isempty(bgLevel)
        bgLevel = sMri.Histogram.bgLevel;
    end

    % ===== CREATE HEAD MASK =====
    % Threshold mri to the requested level
    headmask = (sMri.Cube(:,:,:,1) > bgLevel);
    % Closing all the faces of the cube
    headmask(1,:,:)   = 0*headmask(1,:,:);
    headmask(end,:,:) = 0*headmask(1,:,:);
    headmask(:,1,:)   = 0*headmask(:,1,:);
    headmask(:,end,:) = 0*headmask(:,1,:);
    headmask(:,:,1)   = 0*headmask(:,:,1);
    headmask(:,:,end) = 0*headmask(:,:,1);
    % Erode + dilate, to remove small components
    if (erodeFactor > 0)
        headmask = headmask & ~mri_dilate(~headmask, erodeFactor);
        headmask = mri_dilate(headmask, erodeFactor);
    end
    % Fill holes
    headmask = (mri_fillholes(headmask, 1) & mri_fillholes(headmask, 2) & mri_fillholes(headmask, 3));

    % ===== CREATE SURFACE =====
    % Compute isosurface
    [sHead.Faces, sHead.Vertices] = mri_isosurface(headmask, 0.5);
    % Downsample to a maximum number of vertices
    maxIsoVert = 60000;
    if (length(sHead.Vertices) > maxIsoVert)
        [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, maxIsoVert./length(sHead.Vertices));
    end
    % Remove small objects
    [sHead.Vertices, sHead.Faces] = tess_remove_small(sHead.Vertices, sHead.Faces);
    % Downsampling isosurface
    if (length(sHead.Vertices) > nVertices)
        [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, nVertices./length(sHead.Vertices));
    end
    % Convert to millimeters
    sHead.Vertices = sHead.Vertices(:,[2,1,3]);
    sHead.Faces    = sHead.Faces(:,[2,1,3]);
    sHead.Vertices = bst_bsxfun(@times, sHead.Vertices, sMri.Voxsize);
    % Convert to SCS
    sHead.Vertices = cs_convert(sMri, 'mri', 'scs', sHead.Vertices ./ 1000);
    % Reduce the final size of the meshed volume
    erodeFinal = 3;
    % Fill holes in surface
    [sHead.Vertices, sHead.Faces] = tess_fillholes(sMri, sHead.Vertices, sHead.Faces, fillFactor, erodeFinal);
end

% ------------------------------------------------- ground truth MNI -> SCS
function [Position_countour_electrodes_SCS, Transformation] = Transfom2SCS(MRIPATH, filename)
% Transform electrode positions to the SCS using the sMri structure.
%   MRIPATH   .mat file of the normalized MRI (with SCS.R and SCS.T)
%   filename  Excel file containing the electrode positions
%   Position_countour_electrodes_SCS  transformed electrode positions in SCS
%   Transformation                    the 4x4 transformation matrix

    % load MRI file
    sMri = load(MRIPATH);
    % Initialize the 4x4 transformation matrix
    Transformation = zeros(4, 4);
    % Set the rotation matrix (top-left 3x3 part)
    Transformation(1:3, 1:3) = sMri.SCS.R;
    % Set the translation vector (top-right 3x1 part)
    Transformation(:, 4) = [sMri.SCS.T; 1];
    % Read the electrode positions from the Excel file
    Position_countour_electrodes = xlsread(filename);
    % Add a row of ones for homogeneous coordinates
    Position_countour_electrodes_MRI = Position_countour_electrodes';
    Position_countour_electrodes_MRI(4, :) = 1;
    % Apply the transformation
    Position_countour_electrodes = Transformation * Position_countour_electrodes_MRI;
    % Extract the transformed positions (first 3 rows)
    Position_countour_electrodes_SCS = Position_countour_electrodes(1:3, :);
    % Transpose the result for final output
    Position_countour_electrodes_SCS = Position_countour_electrodes_SCS';
end

% ------------------------------------------------- ground-truth mesh labels
function Label_vertices = label_mesh_gt(fileList, folderPath, Position_countour_electrodes, current_electrodesize)
% Label_vertices{i}: indices of the vertices of surface i that belong to an
% electrode patch, stacked over all electrodes.
% Pass 1 snaps every electrode onto the nearest vertex of every surface
% (the meshes differ between thresholds, so this is redone per surface).
% Pass 2 grows a patch of radius current_electrodesize (mm) around it.

    % ---- Pass 1: closest vertices
    closest_data = cell(size(Position_countour_electrodes,1), length(fileList));

    for i = 1:length(fileList)
        MRI_mask = load_first_variable(fullfile(folderPath, fileList(i).name));
        vertices = MRI_mask.Vertices * 1000;

        for j = 1:size(Position_countour_electrodes, 1)
            electrode_pos = Position_countour_electrodes(j, :);
            distances = sqrt(sum((vertices - electrode_pos).^2, 2));
            [~, closest_idx] = min(distances);
            closest_data{j, i}.verticegt = vertices(closest_idx, :);
        end
    end

    % ---- Pass 2: label mesh region
    Label_vertices = cell(length(fileList), 1);

    for i = 1:length(fileList)
        MRI_mask = load_first_variable(fullfile(folderPath, fileList(i).name));
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
end

% ------------------------------------------------------- curvature features
function [features_vertices, err_vertices] = extract_features(fileList, folderPath, electrodesize, number_of_thresholds)
% features_vertices{i}: [nVertices x 110] features of surface i (see header).
% err_vertices(i)     : number of vertices of surface i whose neighbourhood
%                       had fewer than 5 vertices (5-nearest fallback used).

    features_vertices = cell(number_of_thresholds, 1);
    err_vertices = zeros(number_of_thresholds, 1);

    for i = 1:length(fileList)

        MRI_mask = load_first_variable(fullfile(folderPath, fileList(i).name));

        % SCS metres -> millimetres, same unit as the radii
        fv.vertices = MRI_mask.Vertices * 1000;
        fv.faces    = MRI_mask.Faces;

        % ----- Per-vertex differential geometry -----
        % PrincipalCurvatures is [2 x nVertices]: row 1 = k1, row 2 = k2
        [PrincipalCurvatures, PrincipalDir1, PrincipalDir2, ...
         FaceCMatrix, VertexCMatrix, Cmagnitude] = GetCurvatures(fv, 1); %#ok<ASGLU>

        % Gaussian curvature K = k1*k2
        GausianCurvature = PrincipalCurvatures(1,:) .* PrincipalCurvatures(2,:);
        % Mean curvature H = (k1+k2)/2
        MeanCurvature = mean(PrincipalCurvatures, 1);
        % Shape index in [-1, 1] (undefined at umbilic points, k1 == k2)
        ShapeIndex = (2 / pi) * atan((PrincipalCurvatures(1,:) + PrincipalCurvatures(2,:)) ./ ...
                                     (PrincipalCurvatures(1,:) - PrincipalCurvatures(2,:)));
        % Curvedness
        Curvedness = sqrt((PrincipalCurvatures(1,:).^2 + PrincipalCurvatures(2,:).^2) / 2);

        % Column-per-feature, row-per-vertex layout
        PrincipalCurvatures = PrincipalCurvatures';
        GausianCurvature    = GausianCurvature';
        MeanCurvature       = MeanCurvature';
        ShapeIndex          = ShapeIndex';
        Curvedness          = Curvedness';

        % [nVertices x 10] feature matrix
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

                % Euclidean distance from vertex j to every other vertex
                distances = sqrt(sum((fv.vertices - fv.vertices(j,:)).^2, 2));

                % Vertices inside the sphere of radius current_electrodesize
                close_vertices_idx = find(distances <= current_electrodesize);

                % Fallback for sparse regions: take the 5 nearest instead
                if size(close_vertices_idx,1) < 5
                    [~, close_vertices_idx] = mink(distances, 5);
                    err_vertices(i,:) = err_vertices(i,:) + 1;
                end

                neighborAllFeatures = AllFeatures(close_vertices_idx,:);

                Mean_AllFeatures_total(j,:) = mean(neighborAllFeatures, 1);
                Std_AllFeatures_total(j,:)  = std(neighborAllFeatures, 0, 1);
            end

            % Append this scale's 20 columns
            features_vertices{i} = [features_vertices{i} ...
                                    Mean_AllFeatures_total Std_AllFeatures_total];
        end

        fprintf('  surface %2d / %d: %d vertices, %d features\n', ...
                i, length(fileList), size(features_vertices{i}, 1), size(features_vertices{i}, 2));
    end
end