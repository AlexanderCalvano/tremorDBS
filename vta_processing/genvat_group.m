clc; clear; close all;

% define LEAD-DBS directory
baseFolder = '/path/to/derivatives/leaddbs';

% Get list of all subjects
subjects = dir(fullfile(baseFolder, 'sub-*'));
subjects = subjects([subjects.isdir]); 

% Define stimulation parameters
amplitudes = 0.5:0.5:5; % Amplitudes from 0mA to 5mA
contacts = 1:8; % We have 8 contacts per hemisphere

%Loop over subjects
for i = 1:length(subjects)
    patientFolder = fullfile(baseFolder, subjects(i).name);
    
    % Loop over hemispheres (Right = 1, Left = 2)
    for sideIdx = 1:2
        side = {'R', 'L'}; % Right = 1, Left = 2
        
        % Explicitly define sideInd
        if strcmpi(side{sideIdx}, 'R')
            sideInd = 1;
        elseif strcmpi(side{sideIdx}, 'L')
            sideInd = 2;
        else
            error('speification doesnt work. Use "R" or "L"');
        end

        % Loop over each contact
        for cathode = contacts
            % loop over every stimulation amplitudes
            for stimAmplitude = amplitudes
                % Define unique label for each VTA
                stimLabel = sprintf('%s_contact-%02d_amp-%0.1fmA', side{sideIdx}, cathode, stimAmplitude);

                % Set anode as case (0) for monopolar stimulation
                anode = [0];

                % Define stimulation type (current-based, since using mA)
                stimType = 'current';

        
                disp(['Processing Subject: ', subjects(i).name]);
                disp(['Side: ', side{sideIdx}, ' | Side Index: ', num2str(sideInd), ' | Contact: ', num2str(cathode), ' | Amplitude: ', num2str(stimAmplitude)]);

                % Run volume generation
                try
                    ea_genvat_wrapper(patientFolder, stimLabel, side{sideIdx}, [cathode], stimAmplitude, anode, stimType, 0);
                    fprintf('VAT generated: %s | Side: %s | Contact: %d | Amplitude: %.1f mA\n', ...
                            subjects(i).name, side{sideIdx}, cathode, stimAmplitude);
                catch ME
                    fprintf('Error generating VAT: %s | Side: %s | Contact: %d | Amplitude: %.1f mA\n', ...
                            subjects(i).name, side{sideIdx}, cathode, stimAmplitude);
                    disp(ME.message);
                end
            end
        end
    end
end