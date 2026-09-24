function sMri = mni_normalization_brainstorm_EX(subjectName, mriFilePath, outFilePath)
% MNI_NORMALIZATION_BRAINSTORM_EX  Import a NIfTI MRI into Brainstorm and MNI-normalize it.
%
%   sMri = mni_normalization_brainstorm_EX(subjectName, mriFile, outMatFile)
%
%   Brainstorm must already be running with a protocol selected. The main
%   script handles both.
%
%   INPUTS
%     subjectName  Name of the subject in the Brainstorm database
%     mriFile      Full path to the input NIfTI file (.nii / .nii.gz)
%     outMatFile   Full path of the .mat FILE (not a folder) where the
%                  normalized MRI structure is saved
%
%   OUTPUT
%     sMri         Brainstorm MRI structure with the MNI transformation
%                  and fiducials (SCS: NAS/LPA/RPA) defined

if nargin < 3
        error('Three inputs are required: subjectName, mriFilePath and outFilePath');
end
% Start a new report
    sFiles = [];
    bst_report('Start', sFiles);
% Process: Import MRI
    sFiles = bst_process('CallProcess', 'process_import_mri', sFiles, [], ...
'subjectname', subjectName, ...
'mrifile',     {mriFilePath, 'Nifti1'}, ...
'nas',         [0, 0, 0], ...
'lpa',         [0, 0, 0], ...
'rpa',         [0, 0, 0], ...
'ac',          [0, 0, 0], ...
'pc',          [0, 0, 0], ...
'ih',          [0, 0, 0]);
% Process: MNI normalization
    sFiles = bst_process('CallProcess', 'process_mni_normalize', sFiles, [], ...
'subjectname', subjectName, ...
'method',      'maff8', ...  % Affine registration using SPM mutual information algorithm
'uset2',       0);

% Load the normalized MRI structure and save it to the user-defined path
ProtocolInfo = bst_get('ProtocolInfo');
if isempty(ProtocolInfo)
    % create one, or select an existing one by name
    gui_brainstorm('CreateProtocol', 'MyProtocol', 0, 0);
    % existing:  iProtocol = bst_get('Protocol', 'MyProtocol');
    %            gui_brainstorm('SetCurrentProtocol', iProtocol);
end
    sSubject = bst_get('Subject', subjectName);
    sMri     = in_mri_bst(sSubject.Anatomy(sSubject.iAnatomy).FileName);
    outDir   = bst_fileparts(outFilePath);
    if ~isempty(outDir) && ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    bst_save(outFilePath, sMri, 'v7');

% Save and display report
    ReportFile = bst_report('Save', sFiles);
    bst_report('Open', ReportFile);
end