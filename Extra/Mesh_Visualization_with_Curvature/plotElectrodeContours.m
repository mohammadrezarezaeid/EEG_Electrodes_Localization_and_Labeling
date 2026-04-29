function plotElectrodeContours(Position_countour_electrodes_SCS, displayLabels, color,radius_size)
    % plotElectrodeContours - Plot electrode contours in 3D space.
    % Inputs:
    %   Position_countour_electrodes_SCS: Nx3 matrix of electrode positions
    %   displayLabels: (optional) Boolean flag to display index labels (default: false)
    %   color: (optional) Color of the electrode contour (default: 'r')

    if nargin < 2
        displayLabels = false; % Default to not display labels
    end
    if nargin < 3
        color = 'r'; % Default color is red
    end

    % Radius of the electrodes' visualization
    radius_size2 = radius_size;

    % Generate sphere coordinates
    [xxx2, yyy2, zzz2] = sphere;
    xxx2 = xxx2 * radius_size2;
    yyy2 = yyy2 * radius_size2;
    zzz2 = zzz2 * radius_size2;

    % Create a new figure

    hold on;

    % Plot each electrode position as a sphere
    for iii = 1:size(Position_countour_electrodes_SCS, 1)
        plot3(xxx2 + Position_countour_electrodes_SCS(iii, 1), ...
              yyy2 + Position_countour_electrodes_SCS(iii, 2), ...
              zzz2 + Position_countour_electrodes_SCS(iii, 3), ...
              '--', 'Color', color, 'MarkerSize', 540, 'MarkerFaceColor', '#D9FFFF');
    end

    % Optional: Adding index as text label on plot
    if displayLabels
        for iii = 1:size(Position_countour_electrodes_SCS, 1)
            text(Position_countour_electrodes_SCS(iii, 1), ...
                 Position_countour_electrodes_SCS(iii, 2), ...
                 Position_countour_electrodes_SCS(iii, 3), ...
                 num2str(iii), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
        end
    end


    xlabel('X-axis');
    ylabel('Y-axis');
    zlabel('Z-axis');
    title('Electrode Contours');
    grid on;
    axis equal; % Keep aspect ratio
    view(3)
end
