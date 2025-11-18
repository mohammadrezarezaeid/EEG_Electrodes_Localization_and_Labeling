%%
clc
clear all
close all

%%
% Define the main folder path
mainFolderPath = 'C:\PhD\Aim1_final_code\Dataset_surface_Extracted_Hist_match_64_electrodes\';

%% Parameters

electrodesize = [6, 8, 10, 12, 15];
%%


% Loop through each subject from HC003 to HC023
for subjectNum = 3:23
% Generate the subject folder path based on the subject number
folderPath = fullfile(mainFolderPath, sprintf('HC%03d', subjectNum));
    
% Check if the subject folder exists
if ~isfolder(folderPath)
   fprintf('Folder for HC%03d is missing. Skipping.\n', subjectNum);
   continue;
end
    
% Get a list of all the .mat files in the folder that match 'result_with_surf*.mat'
fileList = dir(fullfile(folderPath, 'result_with_surf*.mat'));
    
% Check if there are any files to process
if isempty(fileList)
   fprintf('No files found for HC%03d. Skipping.\n', subjectNum);
   continue;
end
%%
% Loop through each file and apply the code
tic
features_vertices=cell(20, 1);
err_vertices=zeros(20,1);
for i = 1:length(fileList)

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

    [PrincipalCurvatures,PrincipalDir1,PrincipalDir2,FaceCMatrix,VertexCMatrix,Cmagnitude] = GetCurvatures(fv, 1);

    GausianCurvature=PrincipalCurvatures(1,:).*PrincipalCurvatures(2,:);
    MeanCurvature=mean(PrincipalCurvatures,1);
    % Calculate the shape index
    ShapeIndex = (2 / pi) * atan((PrincipalCurvatures(1,:) + PrincipalCurvatures(2,:)) ./ (PrincipalCurvatures(1,:) - PrincipalCurvatures(2,:)));
    Curvedness = sqrt((PrincipalCurvatures(1,:).^2 + PrincipalCurvatures(2,:).^2) / 2);

    PrincipalCurvatures=PrincipalCurvatures';
    GausianCurvature=GausianCurvature';
    MeanCurvature=MeanCurvature';
    ShapeIndex=ShapeIndex';
    Curvedness=Curvedness';

    features_vertices{i}=[features_vertices{i} PrincipalCurvatures abs(PrincipalCurvatures) PrincipalDir1 PrincipalDir2 ...
        Cmagnitude GausianCurvature MeanCurvature abs(GausianCurvature) abs(MeanCurvature) ShapeIndex Curvedness];
    

    for dIdx = 1:length(electrodesize)
        current_electrodesize = electrodesize(dIdx);

        S_PrincipalCurvatures_total=zeros(size(PrincipalCurvatures));
        S_PrincipalDir1_total=zeros(size(PrincipalDir1));
        S_PrincipalDir2_total=zeros(size(PrincipalDir2));
        S_MeanCurvature_total=zeros(size(MeanCurvature));
        S_ShapeIndex_total=zeros(size(ShapeIndex));
        S_Cmagnitude_total=zeros(size(Cmagnitude));
        S_GausianCurvature_total=zeros(size(GausianCurvature));
        S_Curvedness_total=zeros(size(Curvedness));

        Mean_PrincipalCurvatures_total=zeros(size(PrincipalCurvatures));
        Mean_MeanCurvature_total=zeros(size(MeanCurvature));
        Mean_GausianCurvature_total=zeros(size(GausianCurvature));



        Std_PrincipalCurvatures_total=zeros(size(PrincipalCurvatures));
        Std_MeanCurvature_total=zeros(size(MeanCurvature));
        Std_GausianCurvature_total=zeros(size(GausianCurvature));


  
    
        for j = 1:size(fv.vertices,1)

            % Calculate the distance between the current electrode and all vertices
            distances = sqrt(sum((fv.vertices - fv.vertices(j,:)).^2, 2));

            % Find the indices of vertices within the distance threshold
            close_vertices_idx = find(distances <= current_electrodesize);

            if size(close_vertices_idx,1)<5

                [~,close_vertices_idx]=mink(distances,5);
                err_vertices(i,:)=err_vertices(i,:)+1;

            end



            % Collect Curvedness values of the neighbors
            neighborPrincipalCurvatures = PrincipalCurvatures(close_vertices_idx,:);
            neighborGausianCurvature = GausianCurvature(close_vertices_idx,:);
            neighborMeanCurvature = MeanCurvature(close_vertices_idx,:);
            neighborShapeIndex = ShapeIndex(close_vertices_idx,:);
            neighborCmagnitude = Cmagnitude(close_vertices_idx,:);
            neighborPrincipalDir1 = PrincipalDir1(close_vertices_idx,:);
            neighborPrincipalDir2 = PrincipalDir2(close_vertices_idx,:);
            neighborCurvedness = Curvedness(close_vertices_idx,:);

        
            % Perform SVD on the collected Curvedness values
            % Note: SVD requires a matrix, so ensure the values are arranged in a suitable form
            [~, S_PrincipalCurvatures, ~] = svd(neighborPrincipalCurvatures, 'econ');
            [~, S_GausianCurvature, ~] = svd(neighborGausianCurvature, 'econ');
            [~, S_MeanCurvature, ~] = svd(neighborMeanCurvature, 'econ');
            [~, S_ShapeIndex, ~] = svd(neighborShapeIndex, 'econ');
            [~, S_Cmagnitude, ~] = svd(neighborCmagnitude, 'econ');
            [~, S_PrincipalDir1, ~] = svd(neighborPrincipalDir1, 'econ');
            [~, S_Curvedness, ~] = svd(neighborCurvedness, 'econ');
            [~, S_PrincipalDir2, ~] = svd(neighborPrincipalDir2, 'econ');

            S_PrincipalCurvatures_total(j,:)=diag(S_PrincipalCurvatures)';
            S_PrincipalDir1_total(j,:)=diag(S_PrincipalDir1)';
            S_PrincipalDir2_total(j,:)=diag(S_PrincipalDir2)';
            S_MeanCurvature_total(j,:)=diag(S_MeanCurvature)';
            S_ShapeIndex_total(j,:)=diag(S_ShapeIndex)';
            S_Cmagnitude_total(j,:)=diag(S_Cmagnitude)';
            S_GausianCurvature_total(j,:)=diag(S_GausianCurvature)';
            S_Curvedness_total(j,:)=diag(S_Curvedness)';



            Mean_PrincipalCurvatures_total(j,:)=mean(neighborPrincipalCurvatures);
            Mean_MeanCurvature_total(j,:)=mean(neighborMeanCurvature);
            Mean_GausianCurvature_total(j,:)=mean(neighborGausianCurvature);



            Std_PrincipalCurvatures_total(j,:)=std(neighborPrincipalCurvatures);
            Std_MeanCurvature_total(j,:)=std(neighborMeanCurvature);
            Std_GausianCurvature_total(j,:)=std(neighborGausianCurvature);





        end

        features_vertices{i}=[features_vertices{i} S_PrincipalCurvatures_total S_PrincipalDir1_total S_PrincipalDir2_total S_Cmagnitude_total ...
            S_GausianCurvature_total S_MeanCurvature_total S_ShapeIndex_total S_Curvedness_total Mean_PrincipalCurvatures_total ...
            Mean_MeanCurvature_total Mean_GausianCurvature_total Std_PrincipalCurvatures_total Std_MeanCurvature_total Std_GausianCurvature_total];


    end
end
% Save the features_vertices variable to a file based on the subject number
saveFileName = fullfile('C:\PhD\Aim1_final_code\SavedFeatures_64electrodes\', sprintf('HC%03d_features_vertices.mat', subjectNum));
save(saveFileName, 'features_vertices');

end
toc