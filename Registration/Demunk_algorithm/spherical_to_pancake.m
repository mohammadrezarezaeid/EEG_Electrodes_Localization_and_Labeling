function pancake = spherical_to_pancake(spherical)
% spherical: Nx2 matrix, theta and phi
% convert to pancake coordinates: Nx2 matrix, x and y

phi_pancake = sqrt(spherical(:,2));
phi_pancake(spherical(:,2)<pi/2) = phi_pancake(spherical(:,2)<pi/2) .* sqrt(sin(spherical(spherical(:,2)<pi/2,2)));

pancake = [phi_pancake.*cos(spherical(:,1)) phi_pancake.*sin(spherical(:,1))];
