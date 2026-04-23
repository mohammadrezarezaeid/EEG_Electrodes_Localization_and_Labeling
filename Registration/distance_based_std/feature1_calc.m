function feature1 = feature1_calc(template_x,template_y,detection_x,detection_y,std_prior)
% feature1: prior distribution of electrode location
% template_x,template_y,detection_x,detection_y: 
% coordinates of each detection and each template electrode in pancake images
% std_prior: Expected distance between detection and template

dist_template_detection = pdist2([template_x template_y],[detection_x detection_y])/std_prior;
feature1 = exp(-0.5*dist_template_detection.^2);
