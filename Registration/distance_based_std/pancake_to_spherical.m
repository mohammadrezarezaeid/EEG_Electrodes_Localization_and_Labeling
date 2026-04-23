function spherical = pancake_to_spherical(pancake)
% pancake: Nx2 matrix, x and y
% convert to spherical coordinates: Nx2 matrix, theta and phi

phi = sum(pancake.^2,2);
phi_range = 0:0.01:pi/2;
phi(phi<pi/2) = interp1(phi_range.*sin(phi_range),phi_range,phi(phi<pi/2),'linear','extrap');

spherical = [atan2(pancake(:,2),pancake(:,1)) phi];

