%%
clc
clear all
close all

%%

Subject_name='HC021_Detection';

% Define the folder path where the .mat files are located
folderPath = 'C:\PhD\Aim1_final_code\Dataset_surface_Extracted_Hist_match_64_electrodes\HC021\';

% Get a list of all the .mat files in the folder that match 'result_with_surf*.mat'
fileList = dir(fullfile(folderPath, 'result_with_surf*.mat'));

% Define the main folder
main_folder = 'C:\PhD\Aim1_final_code\Testing_result_64_new\Training_testing\nonweighted\';

%%

gt_filename='C:\PhD\Aim1_final_code\manual_labeling_gt_SCS_64_elect\HC021_electrode_position_SCS.mat';

% Load the .mat file into a structure
gtStruct = load(gt_filename);

% Get the field names of the structure
gtNames = fieldnames(gtStruct);

% Extract the data and assign it to an array
Position_countour_electrodes=gtStruct.(gtNames{1});


Position_countour_electrodes(259:end,:)=[];

%%


for i = 1:length(fileList)

    % Define the subfolder and file path
    subfolder_name = fullfile(main_folder, ['Predicted_Cell_' num2str(i)]);
    file_path = fullfile(subfolder_name, 'predicted_exclude_idx_20.mat');
    
    % Load the .mat file
    data = load(file_path);
    
    % Extract predicted and y_test matrices
    predicted = data.predicted;

    % Construct the full file path
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);
    
    % Load the .mat file
    data_W_electrodes = load(Surface_EXt_filepath);

    % Get the field names of the structure
    data_W_Names = fieldnames(data_W_electrodes);

    % Extract the data and assign it to an array (assuming the field contains MRI_mask)
    MRI_mask = data_W_electrodes.(data_W_Names{1});
    

    vertices=MRI_mask.Vertices*1000;
    faces=MRI_mask.Faces;


    % Find the indices of vertices within the distance threshold
    close_vertices_idx = find(predicted == 1)';
        
    % Find the faces that use these vertices
    % close_faces_idx = find(any(ismember(faces, close_vertices_idx), 2));

    close_faces_idx_logic=any(ismember(faces, close_vertices_idx), 2);
        
     % Store the closest vertices and faces for this point and this mesh
     closest_data{i}.vertices = vertices(close_vertices_idx, :);
     closest_data{i}.verticesIDX=close_vertices_idx;
     closest_data{i}.faceslogic = faces(close_faces_idx_logic, :);


end


%%

total_are_GT=load('total_area_HC009.mat');

for surf_num=1:length(fileList)


total_area_surf=total_are_GT.total_area(:,surf_num);

mean_area_GT=mean(total_area_surf);
std_area_GT=std(total_area_surf);

cluster_vertices=closest_data{surf_num}.verticesIDX;
cluster_faces=closest_data{surf_num}.faceslogic;


% Initialize clustering variables
numVertices = size(cluster_vertices, 1);
numFaces = size(cluster_faces, 1);
visitedFaces = false(numFaces, 1); % Tracks processed faces
visitedVertices = false(numVertices, 1); % Tracks processed vertices
clusters = {}; % To store clusters of vertices and faces
clusterIdx = 0;

patches = {}; 
%%

% Process each seed point
for i = 1:numFaces
    if ~visitedFaces(i)
        % Start a new patch
        patch_faces = i;
        visitedFaces(i) = true;
        
        % Region growing
        queue = patch_faces; % Initialize the queue
        while ~isempty(queue)
            current_face = queue(1);
            queue(1) = []; % Remove from queue
            
            % Find neighboring faces sharing edges with the current face
            neighbors = find(any(ismember(cluster_faces, cluster_faces(current_face, :)), 2));
            for neighbor = neighbors'
                if ~visitedFaces(neighbor)
                    visitedFaces(neighbor) = true;
                    patch_faces = [patch_faces; neighbor];
                    queue = [queue; neighbor];
                end
            end
        end
        
        % Compute the area of the patch
        % area = 0;
        % for face_idx = patch_faces'
        %     v1 = vertices(faces(face_idx, 1), :);
        %     v2 = vertices(faces(face_idx, 2), :);
        %     v3 = vertices(faces(face_idx, 3), :);
        %     area = area + computeFaceArea(v1, v2, v3);
        % end
        
        % Store the patch and its area
        patches{end + 1} = patch_faces;
        % patch_areas(end + 1) = area;
    end
end


%%
% Plot the clusters with unique colors
colors_patches = rand(size(patches,2), 3);

%%

figure;
% Plot the normals for the defined point across all meshes
for i=surf_num%:length(fileList)
    

    % Construct the full file path
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);
    
    % Load the .mat file
    data_W_electrodes = load(Surface_EXt_filepath);

    % Get the field names of the structure
    data_W_Names = fieldnames(data_W_electrodes);

    % Extract the data and assign it to an array (assuming the field contains MRI_mask)
    MRI_mask = data_W_electrodes.(data_W_Names{1});

    fv.vertices=MRI_mask.Vertices*1000;
    fv.faces=MRI_mask.Faces;

    % Assuming fv is defined somewhere in your process
    % Compute curvatures
    PrincipalCurvatures = GetCurvatures(fv, 0);
    c = mean(PrincipalCurvatures,1)';

     % Color the mesh by curvature using mean and standard deviation thresholds
     lower_threshold = mean(c) - std(c);  % Lower threshold
     upper_threshold = mean(c) + std(c);  % Upper threshold
    
     c(c < lower_threshold) = -0.15;  % Set values below the lower threshold
     c(c > upper_threshold) = 0.15;   % Set values above the upper threshold

     cluster_faces=closest_data{i}.faceslogic;

    % figure;
    % Display the convex hull
    % patch('Vertices', fv.vertices, 'Faces', fv.faces, 'FaceVertexCData',c, 'FaceColor', 'interp', 'EdgeColor', 'none', 'FaceAlpha', 0.5);
    % hold on
    for j=1:size(patches,2)
        close_faces_logic = patches{1,j};

        fv_new.vertices=MRI_mask.Vertices*1000;
        fv_new.faces= cluster_faces(close_faces_logic,:);

        % Create a new figure for each file
        % figure;
        hold on;
        p = patch(fv_new);
        colorbar;
        p.EdgeColor = colors_patches(j,:);

        p.FaceVertexCData = c;
        p.FaceColor = 'interp';
        p.FaceAlpha=0.3;
        hold on
    end

        xlabel('X');
        ylabel('Y');
        zlabel('Z');
        axis equal;
        grid on;
        % Configure view and lighting
        view(3);
        title("Curvature of the head surface");
        camlight;
        hold on;
end

%%

area_triangle=cell(size(patches,2),1);

total_area=zeros(size(patches,2),1);

for j=1:size(patches,2)

    close_faces_logic = patches{1,j};

    fv_new.vertices=MRI_mask.Vertices*1000;
    fv_new.faces= cluster_faces(close_faces_logic,:);

    % Extract the vertices of the selected faces
    v1 = fv_new.vertices(fv_new.faces(:,1), :);
    v2 = fv_new.vertices(fv_new.faces(:,2), :);
    v3 = fv_new.vertices(fv_new.faces(:,3), :);

    % Calculate the vectors for two edges of the triangle
    edge1 = v2 - v1;
    edge2 = v3 - v1;

    % Compute the cross product of the edge vectors
    cross_prod = cross(edge1, edge2, 2);

    % Compute the area of the triangles
    areas = 0.5 * sqrt(sum(cross_prod.^2, 2));

    area_triangle{j}=areas;

    total_area(j)=sum(areas);

end


% Calculate mean and standard deviation
mean_area = mean(total_area);
std_area = std(total_area);

% Plot histogram
% figure;
% histogram(total_area, 'Normalization', 'probability', 'FaceColor', [0.2, 0.7, 0.8]);
% xlabel('Total Area');
% ylabel('Probability');
% title('Histogram of Total Areas');
% 
% % Annotate with mean and standard deviation
% hold on;
% xline(mean_area, 'r', 'LineWidth', 2, 'DisplayName', ['Mean: ', num2str(mean_area)]);
% xline(mean_area + std_area, '--r', 'LineWidth', 1.5, 'DisplayName', ['Mean + Std: ', num2str(mean_area + std_area)]);
% xline(mean_area - std_area, '--r', 'LineWidth', 1.5, 'DisplayName', ['Mean - Std: ', num2str(mean_area - std_area)]);
% legend;
% hold off;

%%


% threshold_low=mean_area + 0.5*std_area;
% 
% threshold_high=mean_area - 0.2*std_area;



threshold_low=mean_area_GT + 2*std_area_GT;

threshold_high=mean_area_GT - 2*std_area_GT;


% Filter face groups based on the threshold
filtered_face_groups_low = (total_area >= threshold_low);


% Filter face groups based on the threshold
filtered_face_groups_high = (total_area <= threshold_high);

filtered_face_group_total=filtered_face_groups_low+filtered_face_groups_high;


%%

removed_patches=cell(1,size(patches,2));

for i=1:size(patches,2)

    if filtered_face_group_total(i,:)==0

        removed_patches{1,i}=patches{1,i};

    end


end

removed_patch_total{surf_num}=removed_patches;

end

%%

for i=1:length(fileList)

    removed_patches=removed_patch_total{i};

    % Construct the full file path
    Surface_EXt_filepath = fullfile(folderPath, fileList(i).name);
    
    % Load the .mat file
    data_W_electrodes = load(Surface_EXt_filepath);

    % Get the field names of the structure
    data_W_Names = fieldnames(data_W_electrodes);

    % Extract the data and assign it to an array (assuming the field contains MRI_mask)
    MRI_mask = data_W_electrodes.(data_W_Names{1});

    cluster_faces=closest_data{i}.faceslogic;

    mean_fv_new_faces=[];

    for j=1:size(removed_patches,2)

        close_faces_logic = removed_patches{1,j};

        fv_new.vertices=MRI_mask.Vertices*1000;
        fv_new.faces= cluster_faces(close_faces_logic,:);

        mean_fv_new_faces=[mean_fv_new_faces;mean(fv_new.vertices(unique(fv_new.faces),:))];

    end

    mean_fv_new_faces_total{i}=mean_fv_new_faces;

end



%%

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   i==2 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize variables for concatenated matrix and dictionary
concatMatrix = [];
dictionary = [];

% Iterate through each cell
for i = 2:numel(mean_fv_new_faces_total)
    currentMatrix = mean_fv_new_faces_total{i};
    numRows = size(currentMatrix, 1);
    
    % Concatenate the current matrix
    concatMatrix = [concatMatrix; currentMatrix];
    
    % Add entries to the dictionary
    % Column 1: Cell index, Column 2: Row index in the cell
    dictionary = [dictionary; [repmat(i, numRows, 1), (1:numRows)']];
end


%%

% Set the distance threshold

% Distance threshold
threshold = 12;%12

% Remove rows with NaN values
dataWithoutNaN = concatMatrix(~any(isnan(concatMatrix), 2), :);

% Initialize clustering
numPoints = size(dataWithoutNaN, 1);
clusters = zeros(numPoints, 1); % Cluster assignment for each point
clusterIdx = 0; % Cluster index

% Loop through points to form clusters
for i = 1:numPoints
    if clusters(i) == 0 % If the point is not yet assigned to a cluster
        clusterIdx = clusterIdx + 1; % Create a new cluster
        clusters(i) = clusterIdx;
        % Find all points within the threshold
        distances = sqrt(sum((dataWithoutNaN - dataWithoutNaN(i, :)).^2, 2));
        clusterPoints = find(distances < threshold);
        % Assign these points to the current cluster
        clusters(clusterPoints) = clusterIdx;
    end
end

% Calculate how many clusters have only one member
uniqueClusters = unique(clusters);
singleMemberClustersCount = 0;

singleMemberClusters = zeros(length(uniqueClusters), 1);

for i = 1:length(uniqueClusters)
    if sum(clusters == uniqueClusters(i)) == 1
        singleMemberClustersCount = singleMemberClustersCount + 1;
        singleMemberClusters(i) = 1; % Mark as single-member cluster
    end
end



% Calculate single-member clusters
uniqueClusters = unique(clusters);
singleMemberMeans = [];
multiMemberMeans = [];

for i = 1:length(uniqueClusters)
    clusterPoints = dataWithoutNaN(clusters == uniqueClusters(i), :);
    multiMemberMeans = [multiMemberMeans; mean(clusterPoints, 1)];
    if size(clusterPoints, 1) > 1
        singleMemberMeans = [singleMemberMeans; mean(clusterPoints, 1)];
        
    end
end


% Display results
fprintf('Number of clusters (excluding NaNs): %d\n', clusterIdx);
fprintf('Number of single-member clusters: %d\n', singleMemberClustersCount);


% Create a final cluster array for original data (with NaNs)
finalClusters = nan(size(concatMatrix, 1), 1); % NaNs for rows with NaNs
finalClusters(~any(isnan(concatMatrix), 2)) = clusters;


%%
z_removed=-75;

multiMemberMeans=multiMemberMeans(multiMemberMeans(:,3)>=z_removed,:);

%%

saving_main_folder = 'C:\PhD\Aim1_final_code\Result_Registration_64_elect\';

% Create the full file path
saving_file_path = fullfile(saving_main_folder, Subject_name);

% Save the filtered matrix to the file path
save(saving_file_path, 'multiMemberMeans');


%%

% Initialize matrices for TP and FP
truePositiveCoordsMulti = [];
falseNegativeCoordsMulti = [];

truenegativeCoordsMulti = [];
falsePositiveCoordsMulti = [];

PE_falsepositive=10;

% Initialize counts and assignments
numDetections = size(multiMemberMeans, 1);

% Process multiMemberMeans
assignedMultiMeans = false(size(Position_countour_electrodes, 1), 1);
truePositiveCountMulti = 0;
finalAssignmentsMulti = zeros(numDetections, 1);

assigned_electrodesMulti=[];

for i = 1:numDetections
    % Get distances and indices for multiMemberMeans
    [Idx_multi, D_multi] = knnsearch(Position_countour_electrodes, multiMemberMeans(i, :));
    if D_multi <= PE_falsepositive
        % Assign this mean to the electrode
        assignedMultiMeans(Idx_multi) = true;
        finalAssignmentsMulti(i) = Idx_multi;
        truePositiveCountMulti = truePositiveCountMulti + 1;
        truePositiveCoordsMulti = [truePositiveCoordsMulti; multiMemberMeans(i, :)];

        assigned_electrodesMulti=[assigned_electrodesMulti;i];

    else

        falsePositiveCoordsMulti = [falsePositiveCoordsMulti; multiMemberMeans(i, :)];
    end
end


% Collect False Positives for multiMemberMeans
for j = 1:size(Position_countour_electrodes, 1)
    if ~assignedMultiMeans(j)
        falseNegativeCoordsMulti = [falseNegativeCoordsMulti; Position_countour_electrodes(j, :)];
    else
        truenegativeCoordsMulti = [truenegativeCoordsMulti; Position_countour_electrodes(j, :)];
    end
    
end


%%

% Display results
fprintf('Missed Electrodes: %d\n', size(falseNegativeCoordsMulti));
fprintf('False Positive: %d\n', size(falsePositiveCoordsMulti));

fprintf('number_detections: %d\n', numDetections);
%%

% First plot: All clusters
figure;
hold on;

scatter3(truePositiveCoordsMulti(:, 1), truePositiveCoordsMulti(:, 2), truePositiveCoordsMulti(:, 3), ...
        50, 'blue', 'filled'); % Each cluster gets a unique color

hold on

scatter3(falseNegativeCoordsMulti(:, 1), falseNegativeCoordsMulti(:, 2), falseNegativeCoordsMulti(:, 3), ...
        50, 'y', 'filled'); % Each cluster gets a unique color

hold on
% Plot the original electrode position as a scatter plot

scatter3(truenegativeCoordsMulti(:, 1), truenegativeCoordsMulti(:, 2), truenegativeCoordsMulti(:, 3), ...
        50, 'g', 'filled'); % Each cluster gets a unique color

hold on
% Plot the original electrode position as a scatter plot
scatter3(falsePositiveCoordsMulti(:,1),falsePositiveCoordsMulti(:,2),falsePositiveCoordsMulti(:,3), ...
          50, 'r', 'filled');  % 'g' for green color

xlabel('X');
ylabel('Y');
zlabel('Z');
axis equal;
grid on;
% Configure view and lighting
view(3);
title("Curvature of the head surface");
camlight;


