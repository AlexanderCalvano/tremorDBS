clc; clear; close all;

% Initialise SPM
spm('defaults', 'PET');
spm_jobman('initcfg');

% Define directories
leadDBS_root = 'derivatives/leaddbs';

% Get list of all subjects in Lead-DBS
subjects = dir(fullfile(leadDBS_root, 'sub-subject*'));
subjects = subjects([subjects.isdir]); 

% Loop through each subject
for s = 1:length(subjects)
    subject_id = subjects(s).name;
    disp(['Processing subject: ', subject_id]);

    % Define paths
    subject_path = fullfile(leadDBS_root, subject_id);
    VAT_DIR = fullfile(subject_path, 'stimulations', 'native'); % VTA folder
    STRUCTURAL_DIR = fullfile(subject_path, 'coregistration', 'anat'); % structural image
    DIFFUSION_DIR = fullfile(subject_path, 'diffusion'); % b0.nii
    dti_b0 = fullfile(DIFFUSION_DIR, 'b0.nii');

    % Check if diffusion data exists
    if ~isfile(dti_b0)
        warning('Missing diffusion b0 image for subject %s. Skipping...', subject_id);
        continue;
    end

    % Find correct T1 file
    try
        expected_iso_t1 = fullfile(STRUCTURAL_DIR, ['sub-', subject_id, '_ses-preop_space-anchorNative_desc-preproc_acq-iso_T1w.nii']);
        expected_sag_t1 = fullfile(STRUCTURAL_DIR, ['sub-', subject_id, '_ses-preop_space-anchorNative_desc-preproc_acq-sag_T1w.nii']);

        disp(['Checking for ISO T1: ', expected_iso_t1]);
        disp(['Checking for SAG T1: ', expected_sag_t1]);

        % Search for T1 images
        if isfile(expected_iso_t1)
            anat_t1 = expected_iso_t1;
            disp(['Using ISO T1 file: ', anat_t1]);
        elseif isfile(expected_sag_t1)
            anat_t1 = expected_sag_t1;
            disp(['Using SAG T1 file: ', anat_t1]);
        else
           
            t1_files = dir(fullfile(STRUCTURAL_DIR, '*_T1w.nii'));
            if ~isempty(t1_files)
                anat_t1 = fullfile(STRUCTURAL_DIR, t1_files(1).name);
                disp(['Using fallback T1 file: ', anat_t1]);
            else
                error('No matching T1 file found.');
            end
        end
    catch
        warning('Missing T1 for subject %s. Skipping...', subject_id);
        continue;
    end

    % Get all stimulation folders (VTAs)
    vat_folders = dir(fullfile(VAT_DIR, '*_contact-*'));
    vat_folders = vat_folders([vat_folders.isdir]);

    for vf = 1:length(vat_folders)
        vat_folder_name = vat_folders(vf).name;
        vat_folder_path = fullfile(VAT_DIR, vat_folder_name);
        disp(['Processing VAT: ', vat_folder_name]);

        % Find the file inside the folder
        vat_files = dir(fullfile(vat_folder_path, '*.nii')); % Get all NIfTI files
        if isempty(vat_files)
            warning('No VAT file found in %s. Skipping...', vat_folder_name);
            continue;
        end

        vat_path = fullfile(vat_folder_path, vat_files(1).name); 

        % Define output path
        vat_resampled = fullfile(vat_folder_path, ['r', vat_files(1).name, '.gz']);

        % SPM Coregistration
        disp(['Running SPM Coregistration for VAT: ', vat_files(1).name]);
        matlabbatch = {};
        matlabbatch{1}.spm.spatial.coreg.estimate.ref = {dti_b0}; % Reference: Diffusion b0
        matlabbatch{1}.spm.spatial.coreg.estimate.source = {anat_t1}; % Source: T1
        matlabbatch{1}.spm.spatial.coreg.estimate.other = {vat_path}; % VTA as "other image"

        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

        try
            spm_jobman('run', matlabbatch);
            disp('SPM Coregistration completed.');
        catch ME
            warning('SPM Coregistration failed for VAT %s. Error: %s', vat_files(1).name, ME.message);
            continue;
        end

        % FLIRT Resampling to Diffusion Space
        disp('Running FLIRT for VAT resampling...');

        % Ensure FSL is correctly set
        setenv('PATH', [getenv('PATH') ':/Users/alexandercalvano/fsl/bin']);
        setenv('FSLOUTPUTTYPE', 'NIFTI_GZ');

        shell_command = sprintf( ...
            'flirt -in %s -ref %s -applyxfm -usesqform -out %s -interp nearestneighbour', ...
            vat_path, dti_b0, vat_resampled);
        [status, cmdout] = system(shell_command);

        if status ~= 0
            warning('FLIRT failed for VAT in %s: %s', vat_folder_name, cmdout);
        else
            disp(['FLIRT completed for ', vat_files(1).name]);
        end

        disp(['Completed VTA processing for ', vat_folder_name]);
    end

    disp(['Completed processing for subject: ', subject_id]);
end

disp('All VTAs processed !');