function [rownonZeroElements_template, colnonZeroElements_template, n_template] = map2curvaturemap(electrodessss_sort, resolution)

    % Calculate spherical coordinates (theta and phi) from Cartesian coordinates
    template_theta = atan2(electrodessss_sort(:,2), electrodessss_sort(:,1));
    template_phi = atan2(sqrt(sum(electrodessss_sort(:,1:2).^2, 2)), electrodessss_sort(:,3));

    % Convert spherical coordinates to pancake coordinates
    template_pancake = spherical_to_pancake([template_theta template_phi]);

    % Number of electrodes in the template
    n_template = size(template_pancake, 1);

    % Define grid resolution for the pancake image
    dx = resolution; % resolution in x-axis
    dy = resolution; % resolution in y-axis
    x_registration = -2:dx:2; % x-axis registration points
    y_registration = -2:dy:2; % y-axis registration points

    % Create a 2D histogram (image) from the pancake coordinates
    image_template = histcounts2(template_pancake(:,2), template_pancake(:,1), [x_registration Inf], [y_registration Inf]);

    % Find non-zero elements in the image
    [rownonZeroElements_template, colnonZeroElements_template] = find(image_template ~= 0);

    % Plot the image and highlight the non-zero elements
    figure;
    imagesc(image_template);
    hold on;
    for iiii = 1:size(colnonZeroElements_template, 1)
        plot(rownonZeroElements_template(iiii), colnonZeroElements_template(iiii), 'w+');
        hold on;
    end
    title("WO/NAN");

end
