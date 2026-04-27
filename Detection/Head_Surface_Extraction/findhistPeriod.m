function [start_idx, end_idx] = findhistPeriod(MRIPATH, diff_amplitude, threshold)
    % x: x-values of the histogram (bin centers)
    % y: y-values of the histogram (bin counts)
    % threshold: the level in x-values where the period should end
    % diff_amplitude: the difference in y-values to detect a "significant" change (for start detection)
    %% Check file

    sMri=load(MRIPATH);

    % Check that everything is there
    if ~isfield(sMri, 'Histogram') || isempty(sMri.Histogram) || isempty(sMri.Histogram.bgLevel) || isempty(sMri.Histogram.whiteLevel) || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
        print('You need to set the fiducial points in the MRI first.');
        return
    end

    % If threshold is not provided, use a default value
    if nargin < 3 || isempty(threshold)
        threshold = sMri.Histogram.whiteLevel;  % Set the default to the maximum x-value
        disp(['No x_threshold provided. Using default value: ', num2str(threshold)]);
    end

    x=sMri.Histogram.fncX;
    y=sMri.Histogram.fncY;
    [~,middle_idx]=min(abs(sMri.Histogram.fncX-sMri.Histogram.bgLevel));
  
    %% Creat Period
    
    % Initialize the start and end index 
    start_idx = NaN;
    [~,end_idx] = min(abs(sMri.Histogram.fncX-threshold));
    
    % Find the start of the period by detecting a high difference in y (moving left from the middle)
    for i = middle_idx:-1:2
        if abs(y(i) - y(i-1)) > diff_amplitude
            start_idx = i;
            break;
        end
    end
    
    % Check if x_threshold is smaller than the start point's x-value
    if threshold < start_idx
        error('The threshold x-value is smaller than the start point. Please provide a valid x_threshold.');
    end
    
    % Plot the histogram and the detected start and end points
    figure;
    bar(x+ 0.5, y);
    hold on;
    
    if ~isnan(start_idx)
        plot(x(start_idx), y(start_idx), 'rx', 'MarkerSize', 10, 'LineWidth', 2); % Mark start
    end
    
    if ~isnan(end_idx)
        plot(x(end_idx), y(end_idx), 'bx', 'MarkerSize', 10, 'LineWidth', 2); % Mark end
    end

    if ~isnan(middle_idx)
        plot(x(middle_idx), y(middle_idx), 'gx', 'MarkerSize', 10, 'LineWidth', 2); % Mark middle
    end    
    xlabel('Intensity of MRI images');
    ylabel('Frequency of intensity in MRI images');
    title('MRI images intensity histogram');
    legend('Histogram', 'Air threshold', 'White Matter threshold');
    hold off;
    
end