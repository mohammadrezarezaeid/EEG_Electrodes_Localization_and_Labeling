function [sHead] = headsurfext(MRIPATH, nVertices, erodeFactor, fillFactor, bgLevel)

%% Check file

sMri=load(MRIPATH);

% Check that everything is there
if ~isfield(sMri, 'Histogram') || isempty(sMri.Histogram) || isempty(sMri.SCS) || isempty(sMri.SCS.NAS) || isempty(sMri.SCS.LPA) || isempty(sMri.SCS.RPA)
    print('You need to set the fiducial points in the MRI first.');
    return
end

%% CREATE BGLEVEL
% Threshold mri to the level estimated in the histogram

if nargin < 5 || isempty(bgLevel)
   bgLevel = sMri.Histogram.bgLevel;
end

%% ===== CREATE HEAD MASK =====
% Threshold mri to the level estimated in the histogram



headmask = (sMri.Cube(:,:,:,1) > bgLevel);
% Closing all the faces of the cube
headmask(1,:,:)   = 0*headmask(1,:,:);
headmask(end,:,:) = 0*headmask(1,:,:);
headmask(:,1,:)   = 0*headmask(:,1,:);
headmask(:,end,:) = 0*headmask(:,1,:);
headmask(:,:,1)   = 0*headmask(:,:,1);
headmask(:,:,end) = 0*headmask(:,:,1);
% Erode + dilate, to remove small components
if (erodeFactor > 0)
    headmask = headmask & ~mri_dilate(~headmask, erodeFactor);
    headmask = mri_dilate(headmask, erodeFactor);
end

% Fill holes
headmask = (mri_fillholes(headmask, 1) & mri_fillholes(headmask, 2) & mri_fillholes(headmask, 3));


%% ===== CREATE SURFACE =====
% Compute isosurface

[sHead.Faces, sHead.Vertices] = mri_isosurface(headmask, 0.5);

% Downsample to a maximum number of vertices
maxIsoVert = 60000;
if (length(sHead.Vertices) > maxIsoVert)
    [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, maxIsoVert./length(sHead.Vertices));
end
% Remove small objects

[sHead.Vertices, sHead.Faces] = tess_remove_small(sHead.Vertices, sHead.Faces);

% Downsampling isosurface
if (length(sHead.Vertices) > nVertices)

    [sHead.Faces, sHead.Vertices] = reducepatch(sHead.Faces, sHead.Vertices, nVertices./length(sHead.Vertices));

end
% Convert to millimeters
sHead.Vertices = sHead.Vertices(:,[2,1,3]);
sHead.Faces    = sHead.Faces(:,[2,1,3]);
sHead.Vertices = bst_bsxfun(@times, sHead.Vertices, sMri.Voxsize);
% Convert to SCS
sHead.Vertices = cs_convert(sMri, 'mri', 'scs', sHead.Vertices ./ 1000);

% Reduce the final size of the meshed volume
erodeFinal = 3;
% Fill holes in surface
%if (fillFactor > 0)

    [sHead.Vertices, sHead.Faces] = tess_fillholes(sMri, sHead.Vertices, sHead.Faces, fillFactor, erodeFinal);

% end

