function [Position_countour_electrodes_SCS, Transformation] = Transfom2SCS(MRIPATH, filename)
    % Transfom2SCS transforms electrode positions to the SCS using the sMri structure
    % Inputs:
    %   sMri - A structure containing SCS transformation matrix fields (SCS.R for rotation and SCS.T for translation)
    %   filename - The name of the Excel file containing electrode positions
    % Outputs:
    %   Position_countour_electrodes_SCS - Transformed electrode positions in SCS
    %   Transformation - The 4x4 transformation matrix


    % load MRI file
    sMri=load(MRIPATH);
    % Initialize the 4x4 transformation matrix
    Transformation = zeros(4, 4);

    % Set the rotation matrix (top-left 3x3 part)
    Transformation(1:3, 1:3) = sMri.SCS.R;

    % Set the translation vector (top-right 3x1 part)
    Transformation(:, 4) = [sMri.SCS.T; 1];

    % Read the electrode positions from the Excel file
    Position_countour_electrodes = xlsread(filename);

    % Add a row of ones for homogeneous coordinates
    Position_countour_electrodes_MRI = Position_countour_electrodes';
    Position_countour_electrodes_MRI(4, :) = 1;

    % Apply the transformation
    Position_countour_electrodes = Transformation * Position_countour_electrodes_MRI;

    % Extract the transformed positions (first 3 rows)
    Position_countour_electrodes_SCS = Position_countour_electrodes(1:3, :);

    % Transpose the result for final output
    Position_countour_electrodes_SCS = Position_countour_electrodes_SCS';
end