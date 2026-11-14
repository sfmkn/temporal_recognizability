function summary = generate_TR_batch(startRow,endRow)
% =============================================================
% generate_TR_batch
%
% Restart-safe batch generator for the Temporal Recognizability
% raw-event dataset.
%
% Usage example:
%     summary = generate_TR_batch(1,10);
%
% SAFETY:
%   - Existing event files are SKIPPED.
%   - Existing files are NEVER overwritten.
%   - A failed event does not stop the entire batch.
%   - Every attempted row receives a log entry.
%   - Simulink model is NOT saved.
% =============================================================

%% ------------------------------------------------------------
% 1. Frozen paths/settings
% ------------------------------------------------------------

model = ...
    'IEEE33_TR_TEMPORAL_RECOGNIZABILITY_WORKING_COPY_1';

manifestFile = ...
    ['/MATLAB Drive/Temporal_Recognizability_Dataset/' ...
     'Manifest/TR_V1_Event_Manifest.csv'];

outputFolder = ...
    '/MATLAB Drive/Temporal_Recognizability_Dataset/Raw_Events';

logFolder = ...
    '/MATLAB Drive/Temporal_Recognizability_Dataset/Logs';

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

if ~exist(logFolder,'dir')
    mkdir(logFolder);
end

%% ------------------------------------------------------------
% 2. Load model and frozen manifest
% ------------------------------------------------------------

load_system(model);

M = readtable(manifestFile);

N = height(M);

assert(startRow >= 1, ...
    'STOP: startRow must be at least 1.');

assert(endRow <= N, ...
    'STOP: endRow exceeds manifest size.');

assert(startRow <= endRow, ...
    'STOP: startRow must not exceed endRow.');

fprintf('\n============================================================\n');
fprintf(' TEMPORAL RECOGNIZABILITY — BATCH GENERATOR\n');
fprintf('============================================================\n');
fprintf('Manifest rows : %d to %d\n',startRow,endRow);
fprintf('Events        : %d\n',endRow-startRow+1);
fprintf('Overwrite     : DISABLED\n');
fprintf('Existing files: SKIPPED\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------
% 3. Initialize counters
% ------------------------------------------------------------

nRequested = endRow-startRow+1;

nGenerated = 0;
nSkipped   = 0;
nFailed    = 0;

logEventID = strings(nRequested,1);
logRow     = zeros(nRequested,1);
logStatus  = strings(nRequested,1);
logMessage = strings(nRequested,1);
logSamples = NaN(nRequested,1);
logSeconds = NaN(nRequested,1);

%% ------------------------------------------------------------
% 4. Process requested manifest rows
% ------------------------------------------------------------

for k = 1:nRequested

    row = startRow + k - 1;

    E = M(row,:);

    eventID = string(E.event_id);

    filePath = fullfile( ...
        outputFolder, ...
        char(eventID + ".mat"));

    logEventID(k) = eventID;
    logRow(k) = row;

    fprintf('\n\n############################################################\n');
    fprintf(' ROW %d / %d — %s\n',row,N,eventID);
    fprintf(' Batch progress: %d / %d\n',k,nRequested);
    fprintf('############################################################\n');

    %% --------------------------------------------------------
    % Existing-file restart protection
    % ---------------------------------------------------------

    if exist(filePath,'file')==2

        fprintf('SKIP: file already exists.\n');
        fprintf('%s\n',filePath);

        logStatus(k) = "skipped_existing";
        logMessage(k) = "Existing event file preserved.";

        nSkipped = nSkipped + 1;

        continue;

    end

    %% --------------------------------------------------------
    % Generate event
    % ---------------------------------------------------------

    eventTimer = tic;

    try

        % A. Configure
        info = configure_TR_event(model,E);

        % B. Simulate + extract
        out = simulate_extract_TR_event(model,E);

        % C. Save with overwrite protection
        saveInfo = save_TR_event( ...
            E,info,out,outputFolder,false);

        elapsed = toc(eventTimer);

        % D. Log success
        logStatus(k) = "generated";
        logMessage(k) = "success";
        logSamples(k) = saveInfo.num_samples;
        logSeconds(k) = elapsed;

        nGenerated = nGenerated + 1;

        fprintf('\nBATCH RESULT: GENERATED\n');
        fprintf('Elapsed time: %.2f s\n',elapsed);

    catch ME

        elapsed = toc(eventTimer);

        nFailed = nFailed + 1;

        logStatus(k) = "failed";
        logMessage(k) = string(ME.message);
        logSeconds(k) = elapsed;

        fprintf('\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');
        fprintf('BATCH RESULT: FAILED\n');
        fprintf('Event : %s\n',eventID);
        fprintf('Row   : %d\n',row);
        fprintf('Reason: %s\n',ME.message);
        fprintf('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n');

        % Continue to next event rather than stopping batch.

    end

end

%% ------------------------------------------------------------
% 5. Construct batch log table
% ------------------------------------------------------------

BatchLog = table( ...
    logRow, ...
    logEventID, ...
    logStatus, ...
    logSamples, ...
    logSeconds, ...
    logMessage, ...
    'VariableNames',{ ...
    'manifest_row', ...
    'event_id', ...
    'status', ...
    'num_samples', ...
    'elapsed_seconds', ...
    'message'});

%% ------------------------------------------------------------
% 6. Save batch log
% ------------------------------------------------------------

timestamp = string(datetime('now','Format','yyyyMMdd_HHmmss'));

logFile = fullfile( ...
    logFolder, ...
    char("Batch_" + ...
         string(startRow) + "_" + ...
         string(endRow) + "_" + ...
         timestamp + ".csv"));

writetable(BatchLog,logFile);

%% ------------------------------------------------------------
% 7. Final summary
% ------------------------------------------------------------

fprintf('\n\n============================================================\n');
fprintf(' BATCH COMPLETE\n');
fprintf('============================================================\n');

fprintf('Requested : %d\n',nRequested);
fprintf('Generated : %d\n',nGenerated);
fprintf('Skipped   : %d\n',nSkipped);
fprintf('Failed    : %d\n',nFailed);

fprintf('\nLog file:\n%s\n',logFile);

fprintf('\nExisting event files were not overwritten.\n');
fprintf('Simulink model was not saved.\n');

fprintf('============================================================\n');

%% ------------------------------------------------------------
% 8. Return summary
% ------------------------------------------------------------

summary = struct;

summary.start_row = startRow;
summary.end_row = endRow;
summary.requested = nRequested;
summary.generated = nGenerated;
summary.skipped = nSkipped;
summary.failed = nFailed;
summary.log_file = string(logFile);
summary.log_table = BatchLog;

end