function feature2 = feature2_calc(template_x,template_y,detection_x,detection_y,...
    template_labels, template_is_labeled,detection_labels,detection_is_labeled,std_neighborhood)
% Feature 2: correspondence between electrodes in the neighborhoods of template and detection
% template_x,template_y,detection_x,detection_y: 
% coordinates of each detection and each template electrode in pancake images
% template_labels,template_is_labeled,detection_labels,detection_is_labeled:
% Keep track of which detections have been labeled
% std_neighborhood: Expected distance between each electrode's neighbors with other electrodes 
% based on distance (Pancake coordinate)

n_template = size(template_x,1);
n_detection = size(detection_x,1);

feature2 = zeros(n_template,n_detection);

detection_dist = squareform(pdist([detection_x detection_y]));
template_dist = squareform(pdist([template_x template_y]));
for i=1:n_template
    for j=1:n_detection
        feature2_score = [];


         coordx = template_x-template_x(i)+detection_x(j);
         coordy = template_y-template_y(i)+detection_y(j);
                
         % Find distance from each template to nearest unlabeled detection and
         % from each detection to nearest unlabeled template, as a function of
         % distance to current template/detection
         d = pdist2([coordx coordy],[detection_x detection_y]);
         d_template = [template_dist(:,i) min(d(:,~detection_is_labeled),[],2)];
         d_detection = [detection_dist(:,j) min(d(~template_is_labeled,:),[],1)'];

         % If template is labeled, use distance from labeled detection instead
         d_template(template_is_labeled,2) = diag(d(template_is_labeled,template_labels(template_is_labeled)));
         d_detection(detection_is_labeled,2) = diag(d(detection_labels(detection_is_labeled),detection_labels(detection_is_labeled)));

         % Normalize distance by standard deviation of neighbors
         d_template_norm = d_template(:,2) ./ interp1(std_neighborhood(:,1),std_neighborhood(:,2),template_dist(:,i),'linear','extrap');
         d_detection_norm = d_detection(:,2) ./ interp1(std_neighborhood(:,1),std_neighborhood(:,2),detection_dist(:,j),'linear','extrap');


         feature2(i,j) = geomean(exp(-0.5*d_template_norm.^2));%.*geomean(exp(-0.5*d_detection_norm.^2));
            
    end
end
