function feature1 = feature1_calc(grid_length,template_x,template_y,detection_x,detection_y,std_prior)
% feature1: prior distribution of electrode location
% grid_length: length of pancake image in mm 
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

% Generate prior distributions using a Gaussian centered at each
% electrode 
detection_prior = imgaussfilt(detection_individual,std_prior,'FilterSize',8*round(std_prior)+1,'Padding',0);

% Compute features for all electrodes
% Feature 1: prior distribution of electrode location 
feature1 = zeros(n_template,n_detection);

for i=1:n_template
    feature1(i,:) = squeeze(detection_prior(template_x(i),template_y(i),:));
end

