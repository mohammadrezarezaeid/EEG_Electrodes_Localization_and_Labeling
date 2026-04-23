function cartesian = spherical_to_cartesian(surface, spherical)

% SPHERICAL_TO_CARTESIAN Map spherical coordinates to nearest surface points
% surface   : struct with fields
%               - Vertices (Kx3)
%               - Faces (Mx3) [not used but kept for consistency]
% spherical : Nx2 matrix [theta, phi]
%
% cartesian : Nx3 matrix of corresponding (x,y,z) coordinates on surface
%
% NOTE:
%   - Assumes surface is centered at (0,0,0) in MNI space
%   - Mapping is done via nearest neighbor in (theta, phi) space


%% Extract surface
vertices = surface.Vertices * 1000;  % scale if needed (metre->millimetre)

%% Compute spherical coordinates of surface vertices
x = vertices(:,1);
y = vertices(:,2);
z = vertices(:,3);

r_xy = sqrt(x.^2 + y.^2) + eps;

theta_surf = atan2(y, x);
phi_surf   = atan2(r_xy, z);

%% Input spherical coordinates
theta_query = spherical(:,1);
phi_query   = spherical(:,2);


%% Find closest surface vertex for each query
minDistancepower=zeros(size(theta_surf,1),size(theta_query,1));
minDistancethetaphi=zeros(1,size(phi_query,1));


for ni = 1 : size(theta_query,1)
  for vi = 1 : size(theta_surf,1)
    distancestheta(vi, ni) = abs(theta_query(ni) - theta_surf(vi));
    distancesphi(vi, ni) = abs(phi_query(ni) - phi_surf(vi));
    minDistancepower(vi, ni)=distancestheta(vi, ni)^2+distancesphi(vi, ni)^2;
  end

    [~,minDistancethetaphi(:, ni)]=min(minDistancepower(:, ni));
end

%% Return corresponding Cartesian coordinates
cartesian =vertices(minDistancethetaphi,:);


