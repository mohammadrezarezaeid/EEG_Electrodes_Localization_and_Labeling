% ============================================================
% De Munck et al. EEG Electrode Registration Method
%
% This script implements the semi-automatic method proposed in:
%
%   de Munck, J.C., van Houdt, P.J., Verdaasdonk, R.M.,
%   Ossenblok, P.P.W. 
%   "A semi-automatic method to determine electrode positions
%   and labels from gel artifacts in EEG/fMRI-studies"
%
% Important:
% In the original method, electrode detection relies on manual
% identification of gel artifacts. To ensure a fair comparison,
% we follow the same assumption here by using manually labeled
% electrode positions as input (i.e., detection = ground truth).
%
% Therefore, the detection step is not evaluated in this setup.
% However, the method can also be applied using automatic
% detection results if desired.
%
% The method estimates electrode positions and labels based on
% gel artifacts visible in MRI and aligns them to a template using an affine registration.
%
% Author: Mohammadreza Rezaei-Dastjerdehei
% ============================================================

%%
clc; clear; close all;


%% ================== PARAMETERS ==================

% Subject number and template number
subjectNum = 24;
templateNum = 23;

% Nearest surface to the electrodes
Surface_EXt_filepath = 'result_with_surf237.mat';

% grid resolution based on mean of average radius of an adult human
% skull(approximately ~100 mm)
dx = 0.01;
dy = 0.01;


%% ================== LOAD DATA ==================

det_electrodes = load_electrodes_file (sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));
gt_electrodes  = load_electrodes_file (sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));
tmp_electrodes = load_electrodes_file (sprintf('HC%03d_electrode_position_SCS.mat', templateNum));

%% ================== TRANSFORM TO PANCAKE (CARTESIAN → SPHERICAL → PANCAKE) ==================

temp_spherical=cartesian_to_spherical(tmp_electrodes);
gt_spherical=cartesian_to_spherical(gt_electrodes);
det_spherical=cartesian_to_spherical(det_electrodes);


template_pancake = spherical_to_pancake(temp_spherical);
gt_pancake = spherical_to_pancake(gt_spherical);
det_pancake = spherical_to_pancake(det_spherical);

%% ================== GRID ==================

% Coordinates of pancake image in mm
x_registration = -2:dx:2;
y_registration = -2:dy:2;

%% ================== INITIAL VISUALIZATION (PANCAKE PLOT) ==================

image_gt = histcounts2(gt_pancake(:,2),gt_pancake(:,1),[x_registration Inf],[y_registration Inf]);
image_template=histcounts2(template_pancake(:,2),template_pancake(:,1),[x_registration Inf],[y_registration Inf]);
image_det=histcounts2(det_pancake(:,2),det_pancake(:,1),[x_registration Inf],[y_registration Inf]);

% Plot the position of template's electrodes comparing to detection's electrodes before registration

figure,imagesc(imdilate(image_template,strel('disk',5)) + 2*imdilate(image_det,strel('disk',5)))
title('Detection and template before registration')

%%  ================== DeMUNK Registration  ================== 

% Step 1: Compute the cost matrix (Euclidean distances)
costMatrix = pdist2(det_pancake, template_pancake);

% Step 2: Use the Hungarian algorithm to find optimal assignments
[assignment, cost] = munkres(costMatrix);

% Step 3: Filter matched points based on the assignment
validMatches = assignment > 0; % Find detections that are assigned
matchedDetections = det_pancake(validMatches, :); % Keep matched detections
matchedTemplates = template_pancake(assignment(validMatches), :); % Keep corresponding templates


% Affine registration using labeled electrodes as control points
tform = fitgeotform2d(matchedDetections,matchedTemplates,'affine');
[tempx,tempy] = transformPointsInverse(tform,template_pancake(:,1),template_pancake(:,2));
template_pancake_previous=[template_pancake(:,1) template_pancake(:,2)];
template_reg = [tempx tempy];

% Update template
template_pancake = template_reg;

% Plot the position of template's electrodes comparing to detection's electrodes after registration
image_template_reg = histcounts2(template_pancake(:,1),template_pancake(:,2),[x_registration Inf],[y_registration Inf]);
figure,imagesc(imdilate(image_template_reg,strel('disk',5)) + 2*imdilate(image_gt,strel('disk',5)))
title('Detection and template after registration')


%% ================== BACK TO 3D (PANCAKE → SPHERICAL → CARTESIAN) ==================

spherical_reg = pancake_to_spherical(template_pancake);

% Extract the data and assign it to an array (assuming the field contains MRI_mask)
MRI_mask = load_electrodes_file (Surface_EXt_filepath);
   
% Projection (mapping) spherical ccordinate to the surface (cartesian) for template
EEG_cap_denorm = spherical_to_cartesian(MRI_mask, spherical_reg);

% Projection (mapping) spherical ccordinate to the surface (cartesian) for ground truth
spherical_reg_gt = pancake_to_spherical(gt_pancake);

GT_denorm=spherical_to_cartesian(MRI_mask, spherical_reg_gt);

%% ================== EVALUATION ==================

distances = sqrt(sum((EEG_cap_denorm - GT_denorm).^2, 2));

% Display the distances based one threshold 1 cm (10 mm)
fprintf('Mean error: %.2f mm\n', mean(distances));
fprintf('Std error : %.2f mm\n', std(distances));
fprintf('>10mm     : %d electrodes\n', sum(distances > 10));
