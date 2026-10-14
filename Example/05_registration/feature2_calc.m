function feature2 = feature2_calc(grid_length,template_x,template_y,detection_x,detection_y,...
              template_is_labeled,detection_labels,detection_is_labeled,std_neighborhood,neighborhood_size)
% Feature 2: correspondence between electrodes in the neighborhoods of template and detection
% grid_length: length of pancake image in mm
% template_x,template_y,detection_x,detection_y: 
% coordinates of each detection and each template electrode in pancake images
% template_is_labeled,detection_labels,detection_is_labeled:
% Keep track of which detections have been labeled
% std_neighborhood: Expected distance between each electrode's neighbors with other electrodesin a certain distance (Pancake coordinate)
% neighborhood_size: size of each electrodes neighborhood

n_template = size(template_x,1);
n_detection = size(detection_x,1);

% Generate separate images for each template and detection electrodes
% (OK)
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
detection_neighborhood_prior = imgaussfilt(detection_individual,std_neighborhood,'FilterSize',8*round(std_neighborhood)+1,'Padding',0);
template_neighborhood_prior = imgaussfilt(template_individual,std_neighborhood,'FilterSize',8*round(std_neighborhood)+1,'Padding',0);


% Identify which electrodes are part of the neighborhood of each
% electrode 
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
                 feature2_score = [feature2_score detection_neighborhood_prior(coordx,coordy,detection_labels==m)+eps];
              else
                 feature2_score = [feature2_score sum(detection_neighborhood_prior(coordx,coordy,~detection_is_labeled),3)+eps];
              end
         end

         % Compute score for each electrode in the detection's neighborhood
         for n=detection_neighborhood_idx{j}'
             coordx = detection_x(n)-detection_x(j)+template_x(i);
             coordy = detection_y(n)-detection_y(j)+template_y(i);

             % If detection's neighbor is labeled, check if there is the corresponding labeled template at that location
             % If detection's neighbor is not labeled, check if there is any unlabeled template at that location
             if detection_is_labeled(n)
                feature2_score = [feature2_score template_neighborhood_prior(coordx,coordy,detection_labels(n))+eps];
             else
                feature2_score = [feature2_score sum(template_neighborhood_prior(coordx,coordy,~template_is_labeled),3)+eps];
             end
         end

        % Compute feature 2 as the geometric mean of the scores for all neighbors
        feature2(i,j) = geomean(feature2_score);
    end
end
