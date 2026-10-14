function spherical = cartesian_to_spherical(cartesian)
% cartesian: Nx3 matrix, x,y, and z
% convert to spherical coordinates: Nx2 matrix, theta and phi

theta = atan2(cartesian(:,2),cartesian(:,1));
phi = atan2(sqrt(sum(cartesian(:,1:2).^2,2)),cartesian(:,3));

spherical = [theta phi];