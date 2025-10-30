function vat2diff(varargin)
spm('defaults', 'PET');
spm_jobman('initcfg');

% Define paths
% VAT_DIR        = varargin{1};  % Directory for VAT files
% DIFFUSION_DIR  = varargin{2};  % Diffusion data directory
% STRUCTURAL_DIR = varargin{3};  % Structural T1 image in native space

VAT_DIR        = '/home/armink/tremorDBS/imaging_tremorDBS/subject1/VAT'
DIFFUSION_DIR  = '/home/armink/tremorDBS/imaging_tremorDBS/subject1/diffusion'
STRUCTURAL_DIR = '/home/armink/tremorDBS/imaging_tremorDBS/subject1/structural'

vat_left = fullfile(VAT_DIR, 'vat_left.nii');  % Input VAT left 
vat_right = fullfile(VAT_DIR, 'vat_right.nii');  % Input VAT right 
dti_FA = fullfile(DIFFUSION_DIR, 'b0.nii');  % Reference FA image
vat_left_coreg = fullfile(VAT_DIR, 'vat_left_coreg.nii');  % Output VAT left coregistered
vat_right_coreg = fullfile(VAT_DIR, 'vat_right_coreg.nii');  % Output VAT right coregistered


% SPM Coregistration
disp('Running SPM Coregister: Estimate...');
matlabbatch{1}.spm.spatial.coreg.estimate.source = {fullfile(STRUCTURAL_DIR,'anat_t1.nii')};  
matlabbatch{1}.spm.spatial.coreg.estimate.ref = {dti_FA};
matlabbatch{1}.spm.spatial.coreg.estimate.other = {vat_left; vat_right};  % VAT left and right as "other images"
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';  % Normalized Mutual Information
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];  % Coarse-to-fine sampling in mm
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];  % Registration tolerance
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];  % Smoothing kernel size

%keyboard

% Run SPM Coregister step
spm_jobman('run', matlabbatch);
disp('SPM Coregister: Estimate completed.');

% Save the transformed VATs as new files
disp('Saving coregistered VATs...');
copyfile(vat_left, vat_left_coreg);
copyfile(vat_right, vat_right_coreg);

% Shell command for FLIRT resampling of both VATs
disp('Running FLIRT for resampling VATs...');

% Add FSL binary path
setenv('PATH', [getenv('PATH') ':/Users/alexandercalvano/fsl/bin']);

% VAT left resampling
vat_left_FA_resampled = fullfile(VAT_DIR, 'vat_left_FA_resampled.nii.gz');  % Output VAT left resampled to diffusion space
shell_command_left = sprintf( ...
    'flirt -in %s -ref %s -applyxfm -usesqform -out %s -interp nearestneighbour', ...
    vat_left_coreg, dti_FA, vat_left_FA_resampled);
[status_left, cmdout_left] = system(shell_command_left);

if status_left ~= 0
    error('FLIRT command for VAT left failed: %s', cmdout_left);
else
    disp('FLIRT resampling for VAT left completed successfully.');
end

% VAT right resampling
vat_right_FA_resampled = fullfile(VAT_DIR, 'vat_right_FA_resampled.nii.gz');  % Output VAT right resampled to diffusion space
shell_command_right = sprintf( ...
    'flirt -in %s -ref %s -applyxfm -usesqform -out %s -interp nearestneighbour', ...
    vat_right_coreg, dti_FA, vat_right_FA_resampled);
[status_right, cmdout_right] = system(shell_command_right);

if status_right ~= 0
    error('FLIRT command for VAT right failed: %s', cmdout_right);
else
    disp('FLIRT resampling for VAT right completed successfully.');
end

disp('All processes completed.');
