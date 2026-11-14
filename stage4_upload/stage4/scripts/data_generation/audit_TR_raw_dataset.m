function Audit = audit_TR_raw_dataset()
% =============================================================
% audit_TR_raw_dataset
%
% Independent integrity audit of saved TR_V1 raw-event files.
%
% READ-ONLY:
%   - Does NOT run Simulink
%   - Does NOT modify event files
%   - Does NOT overwrite event files
%   - Does NOT modify the manifest
%
% Checks:
%   1. Required variables exist
%   2. Filename agrees with event ID
%   3. Six waveform channels exist
%   4. waveform/t/tau lengths agree
%   5. All numerical waveform values are finite
%   6. Exactly one tau = 0 sample exists
%   7. Sampling frequency is 100 kHz
%   8. Event length is 8333 or 8334 samples
%   9. Metadata agrees with frozen manifest
%  10. Rf = Rpn
%  11. Saved status = success
% =============================================================

%% ------------------------------------------------------------
% 1. Frozen paths
% ------------------------------------------------------------

manifestFile = ...
    ['/MATLAB Drive/Temporal_Recognizability_Dataset/' ...
     'Manifest/TR_V1_Event_Manifest.csv'];

rawFolder = ...
    '/MATLAB Drive/Temporal_Recognizability_Dataset/Raw_Events';

logFolder = ...
    '/MATLAB Drive/Temporal_Recognizability_Dataset/Logs';

if ~exist(logFolder,'dir')
    mkdir(logFolder);
end

%% ------------------------------------------------------------
% 2. Read frozen manifest
% ------------------------------------------------------------

M = readtable(manifestFile);

fprintf('\n============================================================\n');
fprintf(' TR_V1 RAW DATASET — INDEPENDENT INTEGRITY AUDIT\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------
% 3. Find saved event files
% ------------------------------------------------------------

files = dir(fullfile(rawFolder,'E*.mat'));

nFiles = numel(files);

fprintf('Saved raw-event files found: %d\n',nFiles);

assert(nFiles > 0, ...
    'STOP: No raw-event MAT files were found.');

%% ------------------------------------------------------------
% 4. Prepare audit table
% ------------------------------------------------------------

eventID      = strings(nFiles,1);
manifestRow  = NaN(nFiles,1);
numSamples   = NaN(nFiles,1);
numChannels  = NaN(nFiles,1);
Fs_Hz        = NaN(nFiles,1);

fileValid    = false(nFiles,1);
status       = strings(nFiles,1);
message      = strings(nFiles,1);

%% ------------------------------------------------------------
% 5. Audit each saved file independently
% ------------------------------------------------------------

for k = 1:nFiles

    fileName = files(k).name;
    filePath = fullfile(rawFolder,fileName);

    [~,fileEventID,~] = fileparts(fileName);

    eventID(k) = string(fileEventID);

    fprintf('\n------------------------------------------------------------\n');
    fprintf('AUDITING %s   (%d of %d)\n', ...
        fileEventID,k,nFiles);
    fprintf('------------------------------------------------------------\n');

    try

        %% A. Find corresponding manifest row

        idx = find(string(M.event_id) == string(fileEventID));

        assert(numel(idx)==1, ...
            'Event ID not found exactly once in manifest.');

        manifestRow(k) = idx;

        E = M(idx,:);

        %% B. Load saved file

        S = load(filePath);

        %% C. Required variables

        requiredVars = { ...
            't_event', ...
            'tau', ...
            'waveform', ...
            'metadata'};

        for q = 1:numel(requiredVars)

            assert(isfield(S,requiredVars{q}), ...
                'Missing required variable: %s', ...
                requiredVars{q});

        end

        %% D. Basic dimensions

        t_event = S.t_event;
        tau     = S.tau;
        waveform = S.waveform;
        metadata = S.metadata;

        N = size(waveform,1);
        C = size(waveform,2);

        numSamples(k) = N;
        numChannels(k) = C;

        assert(C==6, ...
            'Waveform does not contain exactly 6 channels.');

        assert(numel(t_event)==N, ...
            't_event length does not match waveform.');

        assert(numel(tau)==N, ...
            'tau length does not match waveform.');

        assert(N==8333 || N==8334, ...
            'Unexpected event sample count.');

        %% E. Numerical integrity

        assert(all(isfinite(waveform(:))), ...
            'Waveform contains NaN or Inf.');

        assert(all(isfinite(t_event(:))), ...
            't_event contains NaN or Inf.');

        assert(all(isfinite(tau(:))), ...
            'tau contains NaN or Inf.');

        %% F. Fault origin

        nZero = sum(tau==0);

        assert(nZero==1, ...
            'Expected exactly one tau=0 sample.');

        %% G. Sampling frequency

        dt = median(diff(t_event));

        FsMeasured = 1/dt;

        Fs_Hz(k) = FsMeasured;

        assert(abs(FsMeasured-100000) < 1, ...
            'Measured sampling frequency is not 100 kHz.');

        %% H. Metadata event ID agrees with filename

        assert(string(metadata.event_id) == ...
               string(fileEventID), ...
            'Metadata event_id does not match filename.');

        %% I. Metadata agrees with manifest

        assert(string(metadata.fault_class) == ...
               string(E.fault_class), ...
            'Fault class mismatch.');

        assert(string(metadata.fault_family) == ...
               string(E.fault_family), ...
            'Fault family mismatch.');

        assert(metadata.fault_bus == E.fault_bus, ...
            'Fault bus mismatch.');

        assert(abs(metadata.fault_resistance_ohm - ...
                   E.fault_resistance_ohm) < 1e-10, ...
            'Fault resistance mismatch.');

        assert(abs(metadata.inception_angle_deg - ...
                   E.inception_angle_deg) < 1e-10, ...
            'Inception angle mismatch.');

        assert(abs(metadata.load_level - ...
                   E.load_level) < 1e-10, ...
            'Load level mismatch.');

        assert(abs(metadata.fault_start_requested_s - ...
                   E.fault_start_requested_s) < 1e-10, ...
            'Requested fault-start time mismatch.');

        assert(metadata.generation_seed == ...
               E.generation_seed, ...
            'Generation seed mismatch.');

        assert(string(metadata.split) == ...
               string(E.split), ...
            'Dataset split mismatch.');

        assert(string(metadata.dataset_version) == ...
               string(E.dataset_version), ...
            'Dataset version mismatch.');

        %% J. Frozen Rf convention

        assert(abs(metadata.fault_resistance_ohm - ...
                   metadata.R_pn_fault_ohm) < 1e-12, ...
            'Rf does not equal Rpn.');

        %% K. Saved sample metadata

        assert(metadata.num_samples == N, ...
            'metadata.num_samples mismatch.');

        assert(metadata.num_pre_fault_samples + ...
            metadata.num_onset_samples + ...
            metadata.num_post_fault_samples == N, ...
            'Pre/onset/post sample counts do not sum to N.');

        assert(metadata.num_onset_samples == 1, ...
            'Metadata does not report exactly one onset sample.');

        %% L. Saved status

        assert(string(metadata.simulation_status) == "success", ...
            'Saved simulation status is not success.');

        %% M. Passed everything

        fileValid(k) = true;
        status(k) = "PASS";
        message(k) = "All integrity checks passed.";

        fprintf('PASS: %s\n',fileEventID);

    catch ME

        fileValid(k) = false;
        status(k) = "FAIL";
        message(k) = string(ME.message);

        fprintf('FAIL: %s\n',fileEventID);
        fprintf('Reason: %s\n',ME.message);

    end

end

%% ------------------------------------------------------------
% 6. Construct audit table
% ------------------------------------------------------------

Audit = table( ...
    eventID, ...
    manifestRow, ...
    numSamples, ...
    numChannels, ...
    Fs_Hz, ...
    fileValid, ...
    status, ...
    message, ...
    'VariableNames',{ ...
    'event_id', ...
    'manifest_row', ...
    'num_samples', ...
    'num_channels', ...
    'Fs_Hz', ...
    'valid', ...
    'status', ...
    'message'});

%% ------------------------------------------------------------
% 7. Dataset-level checks
% ------------------------------------------------------------

nPass = sum(fileValid);
nFail = sum(~fileValid);

n8333 = sum(numSamples==8333);
n8334 = sum(numSamples==8334);

fprintf('\n============================================================\n');
fprintf(' DATASET AUDIT SUMMARY\n');
fprintf('============================================================\n');

fprintf('Files audited : %d\n',nFiles);
fprintf('PASS          : %d\n',nPass);
fprintf('FAIL          : %d\n',nFail);

fprintf('\nSample-count distribution:\n');
fprintf('8333 samples  : %d\n',n8333);
fprintf('8334 samples  : %d\n',n8334);

%% ------------------------------------------------------------
% 8. Save audit report
% ------------------------------------------------------------

timestamp = string(datetime('now', ...
    'Format','yyyyMMdd_HHmmss'));

auditFile = fullfile( ...
    logFolder, ...
    char("TR_V1_Raw_Audit_" + timestamp + ".csv"));

writetable(Audit,auditFile);

fprintf('\nAudit report:\n%s\n',auditFile);

if nFail==0

    fprintf('\nPASS: ALL SAVED RAW EVENTS PASSED THE AUDIT.\n');

else

    fprintf('\nWARNING: %d FILE(S) FAILED THE AUDIT.\n',nFail);
    fprintf('DO NOT continue large-scale generation until reviewed.\n');

end

fprintf('============================================================\n');

end