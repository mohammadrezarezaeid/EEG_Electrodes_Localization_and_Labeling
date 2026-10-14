%% ========================================================================
%  STEP 4 - Registration of detected EEG electrodes
%  ------------------------------------------------------------------------
%  Piecewise linear registration between detected EEG electrodes and a
%  template using:
%    - Feature 1: spatial prior (Gaussian)
%    - Feature 2: distance-based neighborhood consistency
%  The std of feature 2 is a constant parameter based on the distance of
%  each electrode's neighbours from its neighborhood.
%
%  Folder layout (relative to this script; nothing has to be moved):
%    data/              files provided with the example (never modified)
%                         HC024_electrode_position_SCS.mat   template cap
%    results/step1/     input : HC023_electrode_position_SCS.mat   ground truth (evaluation only)
%    results/step3/     input : HC023_Detection.mat          detected electrodes
%                               selected_surface_HC023.mat   head surface
%    results/step4/     output: HC023_registered_electrodes.mat
%                               registered_electrodes [258 x 3], electrode
%                               coordinates after registration (same units
%                               as the input electrode files)
%
%  HOW TO RUN
%    Whole step : press Run (F5), or  run('step4_registration.m')
%    One part   : run the sections in order with Ctrl+Enter.
%
%  Requires MATLAB R2022b+ (fitgeotform2d), Image Processing Toolbox
%  (imgaussfilt, imdilate) and Statistics and Machine Learning Toolbox (geomean).
%  Author: Mohammadreza Rezaei-Dastjerdehei
% ========================================================================
 
%% 0. CONFIGURATION ---------------------------------------------------------
close all;
cfg = struct();
 
% --- Folders (anchored to this script, so the current folder does not matter)
cfg.root = fileparts(mfilename('fullpath'));
if isempty(cfg.root), cfg.root = pwd; end
cfg.dataDir    = fullfile(cfg.root, 'data');
cfg.resultsDir = fullfile(cfg.root, 'results');
cfg.step1Dir   = fullfile(cfg.resultsDir, 'step1');
cfg.step3Dir   = fullfile(cfg.resultsDir, 'step3');
cfg.outDir     = fullfile(cfg.resultsDir, 'step4');
 
% --- Files
cfg.subjectNum    = 23;
cfg.templateNum   = 24;
cfg.detectionFile = fullfile(cfg.step3Dir, sprintf('HC%03d_Detection.mat', cfg.subjectNum));         % Step 3 output
cfg.surfaceFile   = fullfile(cfg.step3Dir, sprintf('selected_surface_HC%03d.mat', cfg.subjectNum));  % Step 3 output
cfg.gtFile        = fullfile(cfg.step1Dir, sprintf('HC%03d_electrode_position_SCS.mat', cfg.subjectNum));  % Step 1 output
cfg.templateFile  = fullfile(cfg.dataDir, sprintf('HC%03d_electrode_position_SCS.mat', cfg.templateNum));
cfg.outFile       = fullfile(cfg.outDir, sprintf('HC%03d_registered_electrodes.mat', cfg.subjectNum));
cfg.nScored       = 258;      % number of electrodes (extra rows are dropped)
 
% --- Pancake grid (resolution based on the average radius of an adult skull, ~100 mm)
cfg.lim = 2;
cfg.dx  = 0.01;
cfg.dy  = 0.01;
 
% --- Features (pancake grid pixels)
cfg.stdPrior         = 30;    % expected distance between detection and template
cfg.stdNeighborhood  = 5;     % expected distance between neighbours (constant)
cfg.neighborhoodSize = 30;    % size of each electrode's neighborhood
 
% --- Iterative labeling
cfg.threshold     = 0.35;     % score threshold (feature1*feature2) from GT and template
cfg.thresholdDiff = 0.01;     % reduction when the template does not move
cfg.stallTol      = 0.00001;  % "template did not move" tolerance
cfg.nIter         = 15;
 
% --- Evaluation
cfg.errThrMM = 10;
 
% --- Display
cfg.plotEachIter = true;      % before/after figures in every iteration
 
cfg.x = -cfg.lim:cfg.dx:cfg.lim;
cfg.y = -cfg.lim:cfg.dy:cfg.lim;
if ~exist(cfg.outDir, 'dir'), mkdir(cfg.outDir); end   % also creates results/ if needed
 
% Stop early with a clear message if an input is missing
inputs = {cfg.detectionFile, 'Step 3'; cfg.surfaceFile, 'Step 3'; ...
          cfg.gtFile, 'Step 1'; cfg.templateFile, 'the example data'};
for k = 1:size(inputs, 1)
    if ~isfile(inputs{k,1})
        error('Missing input %s (expected from %s).', inputs{k,1}, inputs{k,2});
    end
end

%% 1. LOAD ELECTRODES AND MAP TO PANCAKE (CARTESIAN -> SPHERICAL -> PANCAKE)
if ~exist('cfg', 'var'), error('Run Section 0 (configuration) first.'); end

P = struct();
P.det_xyz = load_electrodes_file(cfg.detectionFile);
P.gt_xyz  = load_electrodes_file(cfg.gtFile);
P.tmp_xyz = load_electrodes_file(cfg.templateFile);
P.gt_xyz  = P.gt_xyz (1:cfg.nScored, :);
P.tmp_xyz = P.tmp_xyz(1:cfg.nScored, :);

P.det = spherical_to_pancake(cartesian_to_spherical(P.det_xyz));
P.gt  = spherical_to_pancake(cartesian_to_spherical(P.gt_xyz));
P.tmp = spherical_to_pancake(cartesian_to_spherical(P.tmp_xyz));

plot_overlay(P.tmp, P.det, cfg, 'Template (1) and detections (2): before registration');

%% 2. ITERATIVE LABELING + PIECEWISE LINEAR REGISTRATION --------------------
if ~exist('P', 'var'), error('Run Sections 0 and 1 first.'); end

R = iterative_registration(P.det, P.tmp, cfg);

plot_overlay(R.tmp_reg, P.det, cfg, 'Template (1) and detections (2): after registration');
fprintf('Labeled %d / %d template electrodes from %d detections.\n', ...
        nnz(R.template_is_labeled), cfg.nScored, size(P.det, 1));

%% 3. BACK TO 3-D (PANCAKE -> SPHERICAL -> CARTESIAN) AND SAVE ---------------
if ~exist('R', 'var'), error('Run Sections 0 to 2 first.'); end

MRI_mask = load(cfg.surfaceFile);

F = struct();
F.EEG_cap_denorm = spherical_to_cartesian(MRI_mask, pancake_to_spherical(R.tmp_reg));  % registered template
F.GT_denorm      = spherical_to_cartesian(MRI_mask, pancake_to_spherical(P.gt));       % ground truth

% Final result: electrode coordinates after registration. spherical_to_cartesian
% scales the surface by 1000, so divide by 1000 to save them in input units.
registered_electrodes = F.EEG_cap_denorm / 1000;
save(cfg.outFile, 'registered_electrodes');
fprintf('Saved registered electrodes to %s\n', cfg.outFile);

%% 4. EVALUATION AGAINST GROUND TRUTH ---------------------------------------
if ~exist('F', 'var'), error('Run Sections 0 to 3 first.'); end

E = evaluate(F, cfg);


%% ========================== LOCAL FUNCTIONS ===============================

% ---------------------------------------------------------------- pipeline
function R = iterative_registration(det, tmp, cfg)
% Iterative labeling + piecewise linear registration of the template onto
% the detections (algorithm unchanged from the original script).
    nT = size(tmp, 1);
    nD = size(det, 1);
    gl = numel(cfg.x);       % = numel(cfg.y)
    corners = [cfg.x(1) cfg.y(1); cfg.x(end) cfg.y(1); ...
               cfg.x(1) cfg.y(end); cfg.x(end) cfg.y(end)];

    detection_labels     = zeros(nD, 1);
    detection_is_labeled = false(nD, 1);
    template_is_labeled  = false(nT, 1);

    threshold = cfg.threshold;
    tmp_prev  = [];
    trace     = zeros(cfg.nIter, 4);   % [iteration, threshold, new labels, total labels]

    for it = 1:cfg.nIter
        % Coordinates of each detection and template electrode in the pancake image
        template_x  = round((tmp(:,1) - cfg.x(1)) / cfg.dx) + 1;
        template_y  = round((tmp(:,2) - cfg.y(1)) / cfg.dy) + 1;
        detection_x = round((det(:,1) - cfg.x(1)) / cfg.dx) + 1;
        detection_y = round((det(:,2) - cfg.y(1)) / cfg.dy) + 1;

        % Feature 1: prior distribution of electrode location
        feature1 = feature1_calc(gl, template_x, template_y, detection_x, detection_y, cfg.stdPrior);

        % Feature 2: correspondence between neighborhoods of template and detection
        feature2 = feature2_calc(gl, template_x, template_y, detection_x, detection_y, ...
                                 template_is_labeled, detection_labels, detection_is_labeled, ...
                                 cfg.stdNeighborhood, cfg.neighborhoodSize);

        scaled_score = rescale(feature1 .* feature2);

        % Reduce the threshold if the template did not move in the previous step
        if it > 1 && sum(tmp_prev(:,1) - tmp(:,1)) < cfg.stallTol ...
                  && sum(tmp_prev(:,2) - tmp(:,2)) < cfg.stallTol
            threshold = threshold - cfg.thresholdDiff;
        end

        % Label pairs with a unique high score in both directions
        [template_to_label, detection_to_label] = mutual_matches(scaled_score, threshold);
        template_is_labeled(template_to_label)   = true;
        detection_is_labeled(detection_to_label) = true;
        detection_labels(detection_to_label)     = template_to_label;

        % Piecewise linear registration with labeled electrodes as control points
        tform = fitgeotform2d([det(detection_is_labeled, :); corners], ...
                              [tmp(detection_labels(detection_is_labeled), :); corners], 'pwl');
        [tempx, tempy] = transformPointsInverse(tform, tmp(:,1), tmp(:,2));
        tmp_reg = [tempx tempy];

        if cfg.plotEachIter
            plot_overlay(tmp,     det, cfg, sprintf('Before registration (Iteration %03d)', it));
            plot_overlay(tmp_reg, det, cfg, sprintf('After registration (Iteration %03d)', it));
        end

        % Update template
        tmp_prev = tmp;
        tmp      = tmp_reg;
        trace(it, :) = [it, threshold, numel(template_to_label), nnz(template_is_labeled)];
    end

    R = struct('tmp_reg', tmp, 'detection_labels', detection_labels, ...
               'detection_is_labeled', detection_is_labeled, ...
               'template_is_labeled', template_is_labeled, 'trace', trace);
end

function [template_to_label, detection_to_label] = mutual_matches(scaled_score, threshold)
% A template is labeled if it has only one detection with a high score and
% that detection has only one template with a high score.
    template_to_label  = [];
    detection_to_label = [];
    for jj = 1:size(scaled_score, 1)
        % Two highest peaks for this template
        [peaks_temp, idx_temp] = maxk(scaled_score(jj, :), 2);
        if abs(peaks_temp(1) - peaks_temp(2)) > threshold
            % Two highest peaks for its best detection
            [peaks_det, idx_det] = maxk(scaled_score(:, idx_temp(1)), 2);
            if abs(peaks_det(1) - peaks_det(2)) > threshold && idx_det(1) == jj
                template_to_label  = [template_to_label jj];           %#ok<AGROW>
                detection_to_label = [detection_to_label idx_temp(1)]; %#ok<AGROW>
            end
        end
    end
end

% ---------------------------------------------------------------- evaluation
function E = evaluate(F, cfg)
% Distances between registered template and GT, both projected on the surface.
% spherical_to_cartesian scales vertices by 1000, hence the /1000 below.
    E.distances = sqrt(sum((F.EEG_cap_denorm - F.GT_denorm).^2, 2));
    E.err_mm    = E.distances / 1000;

    fprintf('\n=== Stage 4 evaluation ===\n');
    fprintf('Mean error: %.2f mm\n', mean(E.err_mm));
    fprintf('Std error : %.2f mm\n', std(E.err_mm));
    fprintf('>%gmm     : %d electrodes\n', cfg.errThrMM, sum(E.err_mm > cfg.errThrMM));
end

% ---------------------------------------------------------------- display
function plot_overlay(A, B, cfg, ttl)
% Template (value 1) and detections (value 2) on the pancake image.
    se = strel('disk', 5);
    IA = histcounts2(A(:,2), A(:,1), [cfg.y Inf], [cfg.x Inf]);
    IB = histcounts2(B(:,2), B(:,1), [cfg.y Inf], [cfg.x Inf]);
    figure('Color', 'w');
    imagesc(cfg.x, cfg.y, imdilate(IA, se) + 2 * imdilate(IB, se));
    axis xy equal tight;
    title(ttl, 'FontSize', 14);
    xlabel('X', 'FontSize', 14);
    ylabel('Y', 'FontSize', 14);
end

% ---------------------------------------------------------------- features
function feature1 = feature1_calc(grid_length,template_x,template_y,detection_x,detection_y,std_prior)
    % feature1: prior distribution of electrode location
    % grid_length: length of pancake image
    % template_x,template_y,detection_x,detection_y:
    % coordinates of each detection and each template electrode in pancake images
    % std_prior: Expected distance between detection and template

    n_template = size(template_x,1);
    n_detection = size(detection_x,1);

    % Generate separate images for each template and detection electrodes
    template_individual = zeros(grid_length,grid_length,n_template);
    for i=1:n_template
        template_individual(template_x(i),template_y(i),i) = 1;
    end
    detection_individual = zeros(grid_length,grid_length,n_detection);
    for i=1:n_detection
        detection_individual(detection_x(i),detection_y(i),i) = 1;
    end

    % Generate prior distributions using a Gaussian centered at each electrode
    detection_prior = imgaussfilt(detection_individual,std_prior,'FilterSize',8*round(std_prior)+1,'Padding',0);

    % Feature 1: prior distribution of electrode location
    feature1 = zeros(n_template,n_detection);
    for i=1:n_template
      feature1(i,:) = squeeze(detection_prior(template_x(i),template_y(i),:));
    end
end

function feature2 = feature2_calc(grid_length,template_x,template_y,detection_x,detection_y,...
              template_is_labeled,detection_labels,detection_is_labeled,std_neighborhood,neighborhood_size)
    % Feature 2: correspondence between electrodes in the neighborhoods of template and detection
    % grid_length: length of pancake image
    % template_x,template_y,detection_x,detection_y:
    % coordinates of each detection and each template electrode in pancake images
    % template_is_labeled,detection_labels,detection_is_labeled:
    % Keep track of which detections have been labeled
    % std_neighborhood: Expected distance between each electrode's neighbors with other electrodes in a certain distance (Pancake coordinate)
    % neighborhood_size: size of each electrode's neighborhood

    n_template = size(template_x,1);
    n_detection = size(detection_x,1);

    % Generate separate images for each template and detection electrodes
    template_individual = zeros(grid_length,grid_length,n_template);
    for i=1:n_template
        template_individual(template_x(i),template_y(i),i) = 1;
    end

    detection_individual = zeros(grid_length,grid_length,n_detection);
    for i=1:n_detection
        detection_individual(detection_x(i),detection_y(i),i) = 1;
    end

    % Generate prior distributions using a Gaussian centered at each electrode
    detection_neighborhood_prior = imgaussfilt(detection_individual,std_neighborhood,'FilterSize',8*round(std_neighborhood)+1,'Padding',0);
    template_neighborhood_prior = imgaussfilt(template_individual,std_neighborhood,'FilterSize',8*round(std_neighborhood)+1,'Padding',0);

    % Identify which electrodes are part of the neighborhood of each electrode
    template_neighborhood_idx = cell(n_template,1);
    for i=1:n_template
        template_neighborhood_idx{i} = setdiff(find(any(template_individual(template_x(i)-neighborhood_size:template_x(i)+neighborhood_size,template_y(i)-neighborhood_size:template_y(i)+neighborhood_size,:),[1 2])),i);
    end

    detection_neighborhood_idx = cell(n_detection,1);
    for i=1:n_detection
        detection_neighborhood_idx{i} = setdiff(find(any(detection_individual(detection_x(i)-neighborhood_size:detection_x(i)+neighborhood_size,detection_y(i)-neighborhood_size:detection_y(i)+neighborhood_size,:),[1 2])),i);
    end

    feature2 = zeros(n_template,n_detection);

    for i=1:n_template
        for j=1:n_detection
        feature2_score = [];
        % Compute score for each electrode in the template's neighborhood
        for m=template_neighborhood_idx{i}'
            coordx = template_x(m)-template_x(i)+detection_x(j);
            coordy = template_y(m)-template_y(i)+detection_y(j);
            % If template's neighbor is labeled, check if there is the corresponding labeled detection at that location
            % If template's neighbor is not labeled, check if there is any unlabeled detection at that location
              if template_is_labeled(m)
                 feature2_score = [feature2_score detection_neighborhood_prior(coordx,coordy,detection_labels==m)+eps]; %#ok<AGROW>
              else
                 feature2_score = [feature2_score sum(detection_neighborhood_prior(coordx,coordy,~detection_is_labeled),3)+eps]; %#ok<AGROW>
              end
         end

         % Compute score for each electrode in the detection's neighborhood
         for n=detection_neighborhood_idx{j}'
             coordx = detection_x(n)-detection_x(j)+template_x(i);
             coordy = detection_y(n)-detection_y(j)+template_y(i);

             % If detection's neighbor is labeled, check if there is the corresponding labeled template at that location
             % If detection's neighbor is not labeled, check if there is any unlabeled template at that location
             if detection_is_labeled(n)
                feature2_score = [feature2_score template_neighborhood_prior(coordx,coordy,detection_labels(n))+eps]; %#ok<AGROW>
             else
                feature2_score = [feature2_score sum(template_neighborhood_prior(coordx,coordy,~template_is_labeled),3)+eps]; %#ok<AGROW>
             end
         end

        % Compute feature 2 as the geometric mean of the scores for all neighbors
        feature2(i,j) = geomean(feature2_score);
        end
    end
end

% ------------------------------------------------------- coordinate mapping
function data = load_electrodes_file(filename)
    s = load(filename);
    f = fieldnames(s);
    data = s.(f{1});
end

function spherical = cartesian_to_spherical(cartesian)
% cartesian: Nx3 matrix, x, y, and z
% convert to spherical coordinates: Nx2 matrix, theta and phi

    theta = atan2(cartesian(:,2),cartesian(:,1));
    phi = atan2(sqrt(sum(cartesian(:,1:2).^2,2)),cartesian(:,3));

    spherical = [theta phi];
end

function pancake = spherical_to_pancake(spherical)
% spherical: Nx2 matrix, theta and phi
% convert to pancake coordinates: Nx2 matrix, x and y

    phi_pancake = sqrt(spherical(:,2));
    phi_pancake(spherical(:,2)<pi/2) = phi_pancake(spherical(:,2)<pi/2) .* sqrt(sin(spherical(spherical(:,2)<pi/2,2)));

    pancake = [phi_pancake.*cos(spherical(:,1)) phi_pancake.*sin(spherical(:,1))];
end

function spherical = pancake_to_spherical(pancake)
% pancake: Nx2 matrix, x and y
% convert to spherical coordinates: Nx2 matrix, theta and phi

    phi = sum(pancake.^2,2);
    phi_range = 0:0.01:pi/2;
    phi(phi<pi/2) = interp1(phi_range.*sin(phi_range),phi_range,phi(phi<pi/2),'linear','extrap');

    spherical = [atan2(pancake(:,2),pancake(:,1)) phi];
end

function cartesian = spherical_to_cartesian(surface, spherical)
% Map spherical coordinates to nearest surface points
% surface   : struct with fields
%               - Vertices (Kx3)
%               - Faces (Mx3) [not used but kept for consistency]
% spherical : Nx2 matrix [theta, phi]
% cartesian : Nx3 matrix of corresponding (x,y,z) coordinates on surface
% Mapping is done via nearest neighbor in (theta, phi) space

    % Extract surface
    vertices = surface.Vertices * 1000;

    % Compute spherical coordinates of surface vertices
    x = vertices(:,1);
    y = vertices(:,2);
    z = vertices(:,3);

    r_xy = sqrt(x.^2 + y.^2) + eps;

    theta_surf = atan2(y, x);
    phi_surf   = atan2(r_xy, z);

    % Input spherical coordinates
    theta_query = spherical(:,1);
    phi_query   = spherical(:,2);

    % Find closest surface vertex for each query
    minDistancepower    = zeros(size(theta_surf,1),size(theta_query,1));
    minDistancethetaphi = zeros(1,size(phi_query,1));

    for ni = 1 : size(theta_query,1)
      for vi = 1 : size(theta_surf,1)
        distancestheta(vi, ni) = abs(theta_query(ni) - theta_surf(vi)); %#ok<AGROW>
        distancesphi(vi, ni) = abs(phi_query(ni) - phi_surf(vi));       %#ok<AGROW>
        minDistancepower(vi, ni) = distancestheta(vi, ni)^2 + distancesphi(vi, ni)^2;
      end
        [~,minDistancethetaphi(:, ni)] = min(minDistancepower(:, ni));
    end

    % Return corresponding Cartesian coordinates
    cartesian = vertices(minDistancethetaphi,:);
end