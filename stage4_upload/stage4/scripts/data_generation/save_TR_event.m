function saveInfo = save_TR_event(E,info,out,outputFolder,allowOverwrite)
% =============================================================
% save_TR_event
%
% Saves ONE validated Temporal Recognizability raw event.
%
% Required saved variables:
%   t_event
%   tau
%   waveform
%   metadata
%
% SAFETY:
%   Existing event files are NOT overwritten unless
%   allowOverwrite = true.
% =============================================================

%% ------------------------------------------------------------
% 1. Default overwrite protection
% ------------------------------------------------------------

if nargin < 5
    allowOverwrite = false;
end

eventID = string(E.event_id);

fprintf('\n============================================================\n');
fprintf(' SAVING %s\n',eventID);
fprintf('============================================================\n');

%% ------------------------------------------------------------
% 2. Validate inputs before writing anything
% ------------------------------------------------------------

assert(out.event_id == eventID, ...
    'STOP: extraction output event ID mismatch.');

assert(info.event_id == eventID, ...
    'STOP: configuration info event ID mismatch.');

assert(size(out.waveform,2)==6, ...
    'STOP: waveform must contain six channels.');

assert(numel(out.t_event)==numel(out.tau), ...
    'STOP: t_event/tau length mismatch.');

assert(size(out.waveform,1)==numel(out.tau), ...
    'STOP: waveform/time length mismatch.');

assert(sum(out.tau==0)==1, ...
    'STOP: exactly one tau=0 sample required.');

assert(all(isfinite(out.waveform(:))), ...
    'STOP: waveform contains NaN/Inf.');

assert(abs(out.sampling_frequency_hz-100000)<1, ...
    'STOP: sampling frequency is not 100 kHz.');

%% ------------------------------------------------------------
% 3. Ensure output directory exists
% ------------------------------------------------------------

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

fileName = char(eventID + ".mat");
filePath = fullfile(outputFolder,fileName);

%% ------------------------------------------------------------
% 4. Protect existing files
% ------------------------------------------------------------

if exist(filePath,'file') && ~allowOverwrite

    error(['STOP: Event file already exists and overwrite ' ...
           'protection is ON:\n%s'],filePath);

end

%% ------------------------------------------------------------
% 5. Prepare waveform variables
% ------------------------------------------------------------

t_event = out.t_event;
tau = out.tau;
waveform = out.waveform;

%% ------------------------------------------------------------
% 6. Construct metadata
% ------------------------------------------------------------

metadata = struct;

% Event identity
metadata.event_id = eventID;
metadata.fault_class = string(E.fault_class);
metadata.fault_family = string(E.fault_family);
metadata.fault_bus = E.fault_bus;

% Fault parameters
metadata.fault_resistance_ohm = E.fault_resistance_ohm;
metadata.R_pn_fault_ohm = info.R_pn_fault_ohm;
metadata.R_ng_fault_ohm = info.R_ng_fault_ohm;

metadata.inception_angle_deg = E.inception_angle_deg;
metadata.load_level = E.load_level;

% Requested and sampled fault timing
metadata.fault_start_requested_s = ...
    E.fault_start_requested_s;

metadata.actual_fault_start_s = ...
    out.actual_fault_start_s;

metadata.sampling_offset_s = ...
    out.sampling_offset_s;

metadata.sampling_offset_us = ...
    out.sampling_offset_us;

% Extracted event boundaries
metadata.actual_start_s = ...
    out.actual_start_s;

metadata.actual_end_s = ...
    out.actual_end_s;

metadata.relative_start_s = ...
    out.relative_start_s;

metadata.relative_end_s = ...
    out.relative_end_s;

% Sample information
metadata.num_samples = ...
    out.num_samples;

metadata.num_pre_fault_samples = ...
    out.num_pre_fault_samples;

metadata.num_onset_samples = ...
    out.num_onset_samples;

metadata.num_post_fault_samples = ...
    out.num_post_fault_samples;

metadata.fault_origin_index = ...
    out.fault_origin_index;

% Frozen sampling/system information
metadata.sampling_frequency_hz = ...
    out.sampling_frequency_hz;

metadata.system_frequency_hz = ...
    out.system_frequency_hz;

metadata.window_pre_cycles = 2;
metadata.window_post_cycles = 3;

metadata.channel_order = ...
    ["Va","Vb","Vc","Ia","Ib","Ic"];

% Dataset provenance
metadata.generation_seed = E.generation_seed;
metadata.split = string(E.split);
metadata.dataset_version = string(E.dataset_version);

metadata.model_version = ...
    "IEEE33_TR_TEMPORAL_RECOGNIZABILITY_MASTER";

% File/status information
metadata.waveform_file = string(fileName);
metadata.simulation_status = "success";
metadata.error_message = "";

metadata.fault_origin_definition = ...
    "first recorded sample satisfying t >= requested fault time";

%% ------------------------------------------------------------
% 7. Final metadata consistency checks
% ------------------------------------------------------------

assert(metadata.event_id==out.event_id, ...
    'STOP: metadata event ID mismatch.');

assert(metadata.num_samples==size(waveform,1), ...
    'STOP: metadata sample count mismatch.');

assert(metadata.num_onset_samples==1, ...
    'STOP: metadata onset count incorrect.');

assert(metadata.fault_origin_index == find(tau==0,1), ...
    'STOP: metadata fault-origin index mismatch.');

assert(abs(metadata.R_pn_fault_ohm - ...
    metadata.fault_resistance_ohm)<1e-10, ...
    'STOP: Rpn does not match frozen Rf convention.');

%% ------------------------------------------------------------
% 8. Save
% ------------------------------------------------------------

save(filePath, ...
    't_event', ...
    'tau', ...
    'waveform', ...
    'metadata', ...
    '-v7.3');

%% ------------------------------------------------------------
% 9. Verify file exists
% ------------------------------------------------------------

assert(exist(filePath,'file')==2, ...
    'STOP: event file was not created.');

D = dir(filePath);

fprintf('\nSAVE AUDIT\n');
fprintf('------------------------------------------------------------\n');
fprintf('File       : %s\n',filePath);
fprintf('Size       : %.3f MB\n',D.bytes/1024^2);
fprintf('Samples    : %d\n',metadata.num_samples);
fprintf('Channels   : %d\n',size(waveform,2));
fprintf('tau = 0    : %d sample\n',sum(tau==0));
fprintf('Status     : %s\n',metadata.simulation_status);

%% ------------------------------------------------------------
% 10. Return save information
% ------------------------------------------------------------

saveInfo = struct;

saveInfo.event_id = eventID;
saveInfo.file_name = string(fileName);
saveInfo.file_path = string(filePath);
saveInfo.file_size_bytes = D.bytes;
saveInfo.num_samples = metadata.num_samples;
saveInfo.simulation_status = metadata.simulation_status;

fprintf('\nPASS: %s saved successfully.\n',eventID);
fprintf('============================================================\n');

end