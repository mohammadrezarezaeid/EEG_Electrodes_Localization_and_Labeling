function plotCurvature(MRI_mask,remove_bottom)
    % Input:
    %   MRI_mask: A structure containing the MRI mask with fields Vertices and Faces
    %   remove_bottom: (optional) scalar value indicating the bottom threshold for removal
    %
    % Example usage:
    %   plotCurvature(sHeadwith);

    if nargin < 2
        remove_bottom = [];  % If remove_bottom is not provided, no removal is applied
    end

    % Set up the mesh data from MRI mask
    fv.vertices = MRI_mask.Vertices;
    fv.faces = MRI_mask.Faces;

    % Smooth the mesh
    fv2.vertices = fv.vertices * 1000; 
    fv2.faces = fv.faces;

    % Compute curvatures
    PrincipalCurvatures = GetCurvatures(fv2, 0);

    % BOTTOM REMOVAL
    if ~isempty(remove_bottom)
        % Find vertices below the given bottom threshold
        index_remove_bottom = find(fv2.vertices(:,3) < remove_bottom);
        PrincipalCurvatures(:, index_remove_bottom) = 0;
    end

    % Display the mesh with curvature information
    figure;
    p = patch(fv2);
    colorbar;
    p.EdgeColor = 'none';

    % Color the mesh by curvature using mean and standard deviation thresholds
    c = mean(PrincipalCurvatures, 1)';
    lower_threshold = mean(c) - std(c);  % Lower threshold
    upper_threshold = mean(c) + std(c);  % Upper threshold
    
    c(c < lower_threshold) = -0.15;  % Set values below the lower threshold
    c(c > upper_threshold) = 0.15;   % Set values above the upper threshold

    p.FaceVertexCData = c;
    p.FaceColor = 'interp';

    % Configure view and lighting
    view(3);
    title("Curvature of the head surface");
    camlight;
end