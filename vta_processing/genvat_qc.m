clc; clear; close all;

% define LEAD-DBS directory
baseFolder = '/path/to/derivatives/leaddbs';

% Define expected stimulation parameters
amplitudes = 0.5:0.5:5; 
contacts = 1:8; 
sides = {'R', 'L'}; 

% Get list of all subjects
allSubjects = dir(fullfile(baseFolder, 'sub-subject*'));
allSubjects = allSubjects([allSubjects.isdir]); % Keep only directories

validSubjects = {allSubjects.name};

% initialize missing VAT report
missingVATs = {};

% Looping through each  subject
for i = 1:length(validSubjects)
    subject_id = validSubjects{i};
    vatFolder = fullfile(baseFolder, subject_id, 'stimulations', 'native');

    % Check if VAT directory exists
    if ~isfolder(vatFolder)
        warning('VAT directory missing for subject %s', subject_id);
        missingVATs{end+1} = sprintf('Subject %s: No VAT folder found', subject_id);
        continue;
    end

    % Loop through hemispheres (Right = 1, Left = 2)
    for sideIdx = 1:length(sides)
        side = sides{sideIdx}; 

        % Loop over each contact
        for cathode = contacts
            % Loop over stimulation amplitudes
            for stimAmplitude = amplitudes
                % Define expected VAT folder name
                expectedVATFolder = sprintf('%s_contact-%02d_amp-%0.1fmA', side, cathode, stimAmplitude);
                expectedVATPath = fullfile(vatFolder, expectedVATFolder);

                % Check if the VAT folder exists
                if ~isfolder(expectedVATPath)
                    missingVATs{end+1} = sprintf('missing VTA folder: %s | %s | Contact: %d | Amplitude: %.1f mA', ...
                                                 subject_id, side, cathode, stimAmplitude);
                    continue;
                end

                % Check if the VAT folder is empty
                vatFiles = dir(fullfile(expectedVATPath, '*.nii'));
                if isempty(vatFiles)
                    missingVATs{end+1} = sprintf('empty VTA folder: %s | %s | Contact: %d | Amplitude: %.1f mA', ...
                                                 subject_id, side, cathode, stimAmplitude);
                end
            end
        end
    end
end

reportFile = fullfile(baseFolder, 'missing_VATs.txt');
fid = fopen(reportFile, 'w');
for j = 1:length(missingVATs)
    fprintf(fid, '%s\n', missingVATs{j});
end
fclose(fid);

% show the results
if isempty(missingVATs)
    disp('All VATs are present.');
else
    fprintf('Missing VATs found. Check "%s" for details.\n', reportFile);
    disp(missingVATs');
end