function clean_mri_wire(pathFile, inputFile)
% clean_mri_wire  Removes wire artifacts from MRI using thresholding and morphology
%
%   clean_mri_wire(pathFile, inputFile)
%
%   pathFile  : folder containing the MRI file
%   inputFile : MRI filename (e.g., 'HC009_elect_restore.nii.gz')
%
%   The function outputs:
%       cleaned_<inputFile> — the wire-removed MRI
%       mask_<inputFile>    — the binary mask used

    % Load MRI and header info
    nii  = niftiread(fullfile(pathFile, inputFile));
    info = niftiinfo(fullfile(pathFile, inputFile));

    % Convert to double for processing
    img = double(nii);

    % Step 1: Global thresholding (adjust as needed)
    threshold = 0.02 * max(img(:)); 
    mask = img > threshold;  

    % Step 2: Morphological cleaning
    se = strel('sphere', 1); 
    mask_dilated = imopen(mask, se);

    % Step 3: Keep only the largest connected component (head)
    cc = bwconncomp(mask_dilated, 26);
    numPixels = cellfun(@numel, cc.PixelIdxList);
    [~, idxMax] = max(numPixels);
    mask_cleaned = false(size(mask_dilated));
    mask_cleaned(cc.PixelIdxList{idxMax}) = true;
    mask_dilated = mask_cleaned;     

    % Step 4: Apply mask to remove wires
    clean_img = img .* mask_dilated;

    % Step 5: Save results
    cleanedFile = fullfile(pathFile, ['cleaned_' inputFile]);
    maskFile    = fullfile(pathFile, ['mask_' inputFile]);

    niftiwrite(single(clean_img), cleanedFile, info);
    niftiwrite(single(mask_dilated), maskFile, info);

    fprintf('✅ Saved cleaned file: %s\n', cleanedFile);
    fprintf('✅ Saved mask file: %s\n', maskFile);
end