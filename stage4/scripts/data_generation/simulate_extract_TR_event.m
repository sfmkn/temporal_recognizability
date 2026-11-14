function out = simulate_extract_TR_event(model,E)
% =============================================================
% simulate_extract_TR_event
%
% Simulates ONE already-configured Temporal Recognizability
% event and extracts the frozen raw event window:
%
%                 [-2T , +3T]
%
% relative to the first recorded sample satisfying
%
%             t >= requested fault time.
%
% NO INTERPOLATION
% NO RESAMPLING
% NO PADDING
% NO EVENT FILE SAVING
% =============================================================

%% ------------------------------------------------------------
% 1. Frozen constants
% ------------------------------------------------------------

T  = 1/60;
Ts = 1e-5;
Fs = 1/Ts;

eventID      = string(E.event_id);
tf_requested = E.fault_start_requested_s;

fprintf('\n============================================================\n');
fprintf(' SIMULATING %s\n',eventID);
fprintf('============================================================\n');

%% ------------------------------------------------------------
% 2. Re-establish frozen breaker topology
% ------------------------------------------------------------

CBstate = [ones(1,32) zeros(1,5)];

siminCB = [
    0.0 CBstate
    0.2 CBstate
];

assignin('base','siminCB',siminCB);

%% ------------------------------------------------------------
% 3. Run simulation
% ------------------------------------------------------------

fprintf('Running simulation...\n');

sim(model);

fprintf('Simulation completed.\n');

%% ------------------------------------------------------------
% 4. Retrieve raw Simulink outputs
%
% IMPORTANT:
% Because sim(model) is called from inside this function,
% the To Workspace blocks create Vabc_raw and Iabc_raw
% directly in THIS function workspace.
% ------------------------------------------------------------

assert(exist('Vabc_raw','var')==1, ...
    'Vabc_raw was not produced in the function workspace.');

assert(exist('Iabc_raw','var')==1, ...
    'Iabc_raw was not produced in the function workspace.');

Vraw = Vabc_raw;
Iraw = Iabc_raw;

tV = Vraw.Time(:);
tI = Iraw.Time(:);

V = squeeze(Vraw.Data).';
I = squeeze(Iraw.Data).';

assert(isequal(tV,tI), ...
    'Voltage/current time vectors differ.');

t = tI;

assert(size(V,2)==3, ...
    'Expected three voltage channels.');

assert(size(I,2)==3, ...
    'Expected three current channels.');

assert(all(isfinite(V(:))), ...
    'Voltage contains NaN/Inf.');

assert(all(isfinite(I(:))), ...
    'Current contains NaN/Inf.');

%% ------------------------------------------------------------
% 5. Verify raw sampling
% ------------------------------------------------------------

dtRaw = diff(t);

assert(~isempty(dtRaw), ...
    'Raw time vector is too short.');

TsMeasured = median(dtRaw);
FsMeasured = 1/TsMeasured;

assert(abs(TsMeasured-Ts)<1e-9, ...
    'Raw sampling interval is not 10 us.');

fprintf('\nRAW RECORD\n');
fprintf('------------------------------------------------------------\n');
fprintf('Samples       : %d\n',numel(t));
fprintf('Start         : %.9f s\n',t(1));
fprintf('End           : %.9f s\n',t(end));
fprintf('Measured Fs   : %.3f Hz\n',FsMeasured);

%% ------------------------------------------------------------
% 6. Define sampled fault origin
%
% Frozen convention:
%
% idx0 = first raw sample with t >= requested tf
% actual_fault_start_s = t(idx0)
% tau = t - actual_fault_start_s
% ------------------------------------------------------------

idx0 = find(t >= tf_requested,1,'first');

assert(~isempty(idx0), ...
    'Requested fault time lies outside simulation record.');

tf_sample = t(idx0);

samplingOffset = tf_sample - tf_requested;

assert(samplingOffset >= -1e-12, ...
    'Sampled fault origin precedes requested fault time.');

assert(samplingOffset < Ts + 1e-12, ...
    'Fault-origin offset exceeds one sampling interval.');

tau_all = t - tf_sample;

fprintf('\nFAULT ORIGIN\n');
fprintf('------------------------------------------------------------\n');
fprintf('Requested tf : %.12f s\n',tf_requested);
fprintf('Sampled tf   : %.12f s\n',tf_sample);
fprintf('Offset       : %.6f us\n',samplingOffset*1e6);

%% ------------------------------------------------------------
% 7. Extract frozen [-2T,+3T] event window
%
% IMPORTANT:
% Selection is by TIME CONDITION, not fixed row count.
% ------------------------------------------------------------

eventMask = ...
    tau_all >= -2*T & ...
    tau_all <= 3*T;

t_event = t(eventMask);
tau     = tau_all(eventMask);

V_event = V(eventMask,:);
I_event = I(eventMask,:);

waveform = [V_event I_event];

%% ------------------------------------------------------------
% 8. Extraction integrity checks
% ------------------------------------------------------------

assert(~isempty(t_event), ...
    'Extracted event is empty.');

assert(size(waveform,2)==6, ...
    'Expected six waveform channels.');

assert(numel(t_event)==numel(tau), ...
    't_event/tau length mismatch.');

assert(size(waveform,1)==numel(tau), ...
    'Waveform/time length mismatch.');

assert(all(isfinite(waveform(:))), ...
    'Extracted waveform contains NaN/Inf.');

zeroCount = sum(tau==0);

assert(zeroCount==1, ...
    'Expected exactly one tau=0 sample.');

zeroIndex = find(tau==0,1);

dtEvent = diff(t_event);

assert(all(abs(dtEvent-Ts)<1e-9), ...
    'Extracted event does not preserve 100-kHz sampling.');

%% ------------------------------------------------------------
% 9. Boundary checks
%
% We do NOT require 8333 or 8334 specifically.
% Floating-point representation can alter inclusion of the
% final +3T boundary sample.
% ------------------------------------------------------------

assert(tau(1) >= -2*T-1e-12, ...
    'Event begins before -2T.');

assert(tau(end) <= 3*T+1e-12, ...
    'Event ends after +3T.');

assert(tau(1) < -2*T + Ts + 1e-9, ...
    'First event sample unexpectedly far from -2T.');

assert(tau(end) > 3*T - Ts - 1e-9, ...
    'Last event sample unexpectedly far from +3T.');

%% ------------------------------------------------------------
% 10. Counts
% ------------------------------------------------------------

nPre   = sum(tau<0);
nZero  = sum(tau==0);
nPost  = sum(tau>0);
nTotal = numel(tau);

fprintf('\nEVENT EXTRACTION\n');
fprintf('------------------------------------------------------------\n');
fprintf('Samples       : %d\n',nTotal);
fprintf('Channels      : %d\n',size(waveform,2));
fprintf('tau start     : %.12f s\n',tau(1));
fprintf('tau end       : %.12f s\n',tau(end));
fprintf('Pre-fault     : %d\n',nPre);
fprintf('At onset      : %d\n',nZero);
fprintf('Post-fault    : %d\n',nPost);

%% ------------------------------------------------------------
% 11. Basic RMS diagnostic
%
% Diagnostic only — no class-specific acceptance rule here.
% ------------------------------------------------------------

preMask = ...
    tau >= -T & ...
    tau < 0;

postMask = ...
    tau >= T & ...
    tau < 2*T;

assert(any(preMask), ...
    'No samples available for pre-fault RMS diagnostic.');

assert(any(postMask), ...
    'No samples available for post-fault RMS diagnostic.');

IpreRMS = sqrt(mean(I_event(preMask,:).^2,1));
IpostRMS = sqrt(mean(I_event(postMask,:).^2,1));

fprintf('\nCURRENT RMS DIAGNOSTIC\n');
fprintf('------------------------------------------------------------\n');

fprintf('Pre : Ia %.3f   Ib %.3f   Ic %.3f A\n', ...
    IpreRMS(1),IpreRMS(2),IpreRMS(3));

fprintf('Post: Ia %.3f   Ib %.3f   Ic %.3f A\n', ...
    IpostRMS(1),IpostRMS(2),IpostRMS(3));

%% ------------------------------------------------------------
% 12. Return everything needed by later save function
% ------------------------------------------------------------

out = struct;

out.event_id = eventID;

out.t_event = t_event;
out.tau = tau;
out.waveform = waveform;

out.actual_fault_start_s = tf_sample;
out.sampling_offset_s = samplingOffset;
out.sampling_offset_us = samplingOffset*1e6;

out.actual_start_s = t_event(1);
out.actual_end_s = t_event(end);

out.relative_start_s = tau(1);
out.relative_end_s = tau(end);

out.num_samples = nTotal;
out.num_pre_fault_samples = nPre;
out.num_onset_samples = nZero;
out.num_post_fault_samples = nPost;
out.fault_origin_index = zeroIndex;

out.sampling_frequency_hz = Fs;
out.system_frequency_hz = 60;

out.IpreRMS_A = IpreRMS;
out.IpostRMS_A = IpostRMS;

out.channel_order = ...
    ["Va","Vb","Vc","Ia","Ib","Ic"];

%% ------------------------------------------------------------
% 13. Final audit
% ------------------------------------------------------------

fprintf('\nPASS: simulation completed.\n');
fprintf('PASS: sampled fault origin established.\n');
fprintf('PASS: [-2T,+3T] extraction completed.\n');
fprintf('PASS: exactly one tau=0 sample.\n');
fprintf('PASS: original 100-kHz samples preserved.\n');
fprintf('PASS: no interpolation/resampling/padding.\n');
fprintf('PASS: variable boundary sample count permitted.\n');
fprintf('PASS: six waveform channels returned.\n');

fprintf('\nNO EVENT FILE SAVED.\n');

fprintf('============================================================\n');

end