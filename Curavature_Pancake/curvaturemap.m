function curvature = curvaturemap(MRI_mask, resolution, remove_bottom)
    % curvaturemap generates a curvature map from an MRI mask.
    % INPUTS:
    %   MRI_mask: 3D matrix representing the MRI mask
    %   resolution: 2-element vector [dx, dy] for the grid resolution
    %   remove_bottom: (optional) scalar value indicating the bottom threshold for removal
    % OUTPUT:
    %   curvature: 2D matrix representing the curvature map
   
    if nargin < 3
        remove_bottom = [];  % If remove_bottom is not provided, no removal is applied
    end
    
    % Extract grid resolution
    dx = resolution(1);
    dy = resolution(2);
    
    % Generate grid for the registration
    x_registration = -2:dx:2;
    y_registration = -2:dy:2;

    % Curavure map in 3D
    fv.vertices=MRI_mask.Vertices;
    fv.faces=MRI_mask.Faces;

    % meter to mm
    fv2.vertices = fv.vertices*1000; 
    fv2.faces = fv.faces;%*1000; 

    PrincipalCurvatures= GetCurvatures(fv2,0);


    % BOTTOM REMOVAL
    if ~isempty(remove_bottom)
        % Find vertices below the given bottom threshold
        index_remove_bottom = find(fv2.vertices(:,3) < remove_bottom);
        PrincipalCurvatures(:, index_remove_bottom) = 0;
    end

    % Centroid for EEG
    EEG_centroid = [0 0 0];

    % Convert to pancake view
    x = (fv2.vertices(:,1) - EEG_centroid(1));
    y = (fv2.vertices(:,2) - EEG_centroid(2));
    r = sqrt(x.^2 + y.^2) + eps;
    theta = atan2(y, x);
    phi = atan2(r, fv2.vertices(:,3) - EEG_centroid(3));

    % Convert spherical coordinates to pancake
    fv_pancake = spherical_to_pancake([theta phi]);

    % Map back to x, y coordinates for pancake
    x = fv_pancake(:,1);
    y = fv_pancake(:,2);

    % Generate curvature map with the specified resolution
    curvature = zeros(length(x_registration)-1, length(y_registration)-1);

    for x_idx = 1:length(x_registration)-1
        for y_idx = 1:length(y_registration)-1
            % Mean curvature in each bin
            curvature(x_idx, y_idx) = mean(mean(PrincipalCurvatures(:, ...
                x > x_registration(x_idx) & x <= x_registration(x_idx+1) & ...
                y > y_registration(y_idx) & y <= y_registration(y_idx+1))));
        end
    end

    % Plot the curvature map
    figure;
    imagesc(curvature);
    title('Curvature Map');
    xlabel('X-axis');
    ylabel('Y-axis');
    colorbar;
end
