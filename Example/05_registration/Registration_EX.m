% ============================================================
% Neighborhood Registration for EEG Electrodes (fixed_distance)
%
% This script performs piecewise linear registration between
% detected EEG electrodes and a template using:
%   - Feature 1: Spatial prior (Gaussian)
%   - Feature 2: Distance-based neighborhood consistency
%
% Main difference from distance based std method:
%   - Standard deviation of second feature is a constant parameter based on
%   electrodes' neighbours distance from their neighborhood
%
% Author: Mohammadreza Rezaei-Dastjerdehei
% ============================================================

%%
clc; clear; close all;

%% ================== PARAMETERS ==================

% Subject number and template number
subjectNum = 23;
templateNum = 24;

% Nearest surface to the electrodes
Surface_EXt_filepath = 'selected_surface_HC023.mat';

% grid resolution based on mean of average radius of an adult human
% skull(approximately ~100 mm)
dx = 0.01;
dy = 0.01;

% Expected distance between detection and template (Pancake coordinate)
std_prior = 30; 

% Expected distance between each electrode's neighbors with other
% electrode based on a constant distance (Pancake coordinate)
std_neighborhood = 5;
neighborhood_size =30;
% Expected score threshold (feature1*feature2) extracting from ground truth
% and template
threshold = 0.35;
threshold_diff = 0.01;

% Define if want to plot the before and after registeration in every
% iteration
plot_itr=true;

% Number of iteration
n_iteration=15;

% Numer of electrodes

mainElectrodeCount=258;
%% ================== LOAD DATA ==================

det_electrodes = load_electrodes_file (sprintf('HC%03d_Detection.mat', subjectNum));
gt_electrodes  = load_electrodes_file (sprintf('HC%03d_electrode_position_SCS.mat', subjectNum));
tmp_electrodes = load_electrodes_file (sprintf('HC%03d_electrode_position_SCS.mat', templateNum));

gt_electrodes(mainElectrodeCount+1:end, :) = [];     % scored set only
tmp_electrodes(mainElectrodeCount+1:end, :) = [];     % scored set only

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

grid_length=length(x_registration); % =length(y_registration)

%% ================== INITIAL VISUALIZATION (PANCAKE PLOT) ==================

image_gt = histcounts2(gt_pancake(:,2),gt_pancake(:,1),[x_registration Inf],[y_registration Inf]);
image_template=histcounts2(template_pancake(:,2),template_pancake(:,1),[x_registration Inf],[y_registration Inf]);
image_det=histcounts2(det_pancake(:,2),det_pancake(:,1),[x_registration Inf],[y_registration Inf]);

% Plot the position of template's electrodes comparing to detection's electrodes before registration

figure,imagesc(imdilate(image_template,strel('disk',5)) + 2*imdilate(image_det,strel('disk',5)))
title('Detection and template before registration')

%% ================== INITIALIZATION ==================
% Number of detection and template
n_template = size(template_pancake,1);
n_detection = size(det_pancake,1);

% Keep track of which detections have been labeled
detection_labels = zeros(n_detection,1);
detection_is_labeled = false(n_detection,1);
template_labels = zeros(n_template,1);
template_is_labeled = false(n_template,1);

%%  ================== Piecewise Linere Registration  ================== 

for iteration=1:n_iteration
    
    % Calculate coordinates of each detection and each template electrode
    % in pancake images
    template_x = round((template_pancake(:,1)-x_registration(1))/dx) + 1;
    template_y = round((template_pancake(:,2)-y_registration(1))/dy) + 1;
    detection_x = round((det_pancake(:,1)-x_registration(1))/dx) + 1;
    detection_y = round((det_pancake(:,2)-y_registration(1))/dy) + 1;

    % Feature 1: prior distribution of electrode location
    feature1 = feature1_calc(grid_length,template_x,template_y,detection_x,detection_y,std_prior);

    % Feature 2: correspondence between electrodes in the neighborhoods of template and detection
    feature2 = feature2_calc(grid_length,template_x,template_y,detection_x,detection_y,...
             template_is_labeled,detection_labels,detection_is_labeled,std_neighborhood,neighborhood_size);

    scaled_score = rescale(feature1.*feature2);

    % Identify which detections should be labeled (OK template*detections)
    % Labels should be assigned if a template electrode only has one
    % corresponding detection with a high score, and if that detection only
    % has one template with a high score
    template_to_label1=[];
    detection_to_label1=[];
    
    % Reduce the level of threshold if the template does not move comapring
    % to previous step
    if iteration>1 && sum(template_pancake_previous(:,1)-tempx)<0.00001 && sum(template_pancake_previous(:,2)-tempy)<0.00001
        iteration
        "iteration_apply"
        threshold=threshold-threshold_diff;

    end


    for jj=1:size(template_is_labeled,1)

        [peaks_temp_new, peak_indices_temp_new] = maxk(scaled_score(jj,:), 2);

        % Get the two highest peaks and their indices
        top_two_peaks_temp_new = peaks_temp_new(1:2);
        top_two_peak_indices_temp_new = peak_indices_temp_new(1:2);

        diff_two_peaks_temp_new=abs(top_two_peaks_temp_new(1)-top_two_peaks_temp_new(2));

        if diff_two_peaks_temp_new>threshold

            [peaks_det_new, peak_indices_det_new] = maxk(scaled_score(:,peak_indices_temp_new(1)), 2);

            % Get the three highest peaks and their indices
            top_two_peaks_det_new = peaks_det_new(1:2);
            top_two_peak_indices_det = peak_indices_det_new(1:2);

            diff_two_peaks_det_new=abs(top_two_peaks_det_new(1)-top_two_peaks_det_new(2));

            if diff_two_peaks_det_new>threshold && peak_indices_det_new(1)==jj

                template_to_label1 = [template_to_label1 jj];

                detection_to_label1=[detection_to_label1 peak_indices_temp_new(1)];

            end
        end

    end

    template_is_labeled(template_to_label1) = true;
    detection_is_labeled(detection_to_label1) = true;
    detection_labels(detection_to_label1) = template_to_label1;


    % Piecewise linere registration

    % Nonlinear registration using labeled electrodes as control points
    tform = fitgeotform2d([det_pancake(detection_is_labeled,:);x_registration(1) y_registration(1);x_registration(end) y_registration(1);x_registration(1) y_registration(end);x_registration(end) y_registration(end)],[template_pancake(detection_labels(detection_is_labeled),:);x_registration(1) y_registration(1);x_registration(end) y_registration(1);x_registration(1) y_registration(end);x_registration(end) y_registration(end)],'pwl');
    [tempx,tempy] = transformPointsInverse(tform,template_pancake(:,1),template_pancake(:,2));
    template_pancake_previous=[template_pancake(:,1) template_pancake(:,2)];
    template_reg = [tempx tempy];

    if plot_itr==true
        image_gt = histcounts2(det_pancake(:,1),det_pancake(:,2),[x_registration Inf],[y_registration Inf]);
        image_template_reg = histcounts2(template_pancake(:,1),template_pancake(:,2),[x_registration Inf],[y_registration Inf]);
        figure('Color','w'),imagesc(imdilate(image_template_reg,strel('disk',5)) + 2*imdilate(image_gt,strel('disk',5)))
        title(sprintf('Before registration (Iteration %03d)', iteration), 'FontSize', 14)
        xlabel('X', 'FontSize', 14)
        ylabel('Y', 'FontSize', 14)

        image_template_reg = histcounts2(template_reg(:,1),template_reg(:,2),[x_registration Inf],[y_registration Inf]);
        figure('Color','w'),imagesc(imdilate(image_template_reg,strel('disk',5)) + 2*imdilate(image_gt,strel('disk',5)))
        title(sprintf('After registration (Iteration %03d)', iteration), 'FontSize', 14)
        xlabel('X', 'FontSize', 14)
        ylabel('Y', 'FontSize', 14)        
    end

    % Update template
    template_pancake = template_reg;
end

% Plot the position of template's electrodes comparing to detection's electrodes after registration
image_template_reg = histcounts2(template_pancake(:,1),template_pancake(:,2),[x_registration Inf],[y_registration Inf]);
figure,imagesc(imdilate(image_template_reg,strel('disk',5)) + 2*imdilate(image_gt,strel('disk',5)))
title('Detection and template after registration')


%% ================== BACK TO 3D (PANCAKE → SPHERICAL → CARTESIAN) ==================

spherical_reg = pancake_to_spherical(template_pancake);

% Extract the data and assign it to an array (assuming the field contains MRI_mask)
MRI_mask =load(Surface_EXt_filepath);

   
% Projection (mapping) spherical ccordinate to the surface (cartesian) for template
EEG_cap_denorm = spherical_to_cartesian(MRI_mask, spherical_reg);

% Projection (mapping) spherical ccordinate to the surface (cartesian) for ground truth
spherical_reg_gt = pancake_to_spherical(gt_pancake);

GT_denorm=spherical_to_cartesian(MRI_mask, spherical_reg_gt);

%% ================== EVALUATION ==================

distances = sqrt(sum((EEG_cap_denorm - GT_denorm).^2, 2));

% Display the distances based one threshold 1 cm (10 mm)
fprintf('Mean error: %.2f mm\n', mean(distances)/1000);
fprintf('Std error : %.2f mm\n', std(distances)/1000);
fprintf('>10mm     : %d electrodes\n', sum(distances/1000 > 10));