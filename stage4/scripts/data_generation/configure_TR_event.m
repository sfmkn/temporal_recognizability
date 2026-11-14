function info = configure_TR_event(model,E)
% =============================================================
% configure_TR_event
%
% Configures ONE Temporal Recognizability event from one
% manifest-table row.
%
% Performs:
%   1. Fault-class mapping
%   2. Fault-bus mapping
%   3. Reset of all fault blocks
%   4. Selected fault configuration
%   5. Load scaling FROM NOMINAL
%   6. Breaker topology preparation
%   7. Configuration audit
%
% DOES NOT SIMULATE
% DOES NOT SAVE EVENT FILE
% DOES NOT SAVE SIMULINK MODEL
% =============================================================

%% Event values

eventID = string(E.event_id);
cls     = string(E.fault_class);
fam     = string(E.fault_family);
bus     = E.fault_bus;

Rf      = E.fault_resistance_ohm;
angle   = E.inception_angle_deg;
lambda  = E.load_level;
tf      = E.fault_start_requested_s;

fprintf('\n============================================================\n');
fprintf(' CONFIGURING %s\n',eventID);
fprintf('============================================================\n');

fprintf('Class  : %s\n',cls);
fprintf('Family : %s\n',fam);
fprintf('Bus    : %d\n',bus);
fprintf('Rf/Rpn : %.12f ohm\n',Rf);
fprintf('Angle  : %.12f deg\n',angle);
fprintf('Load   : %.12f pu\n',lambda);
fprintf('tf     : %.12f s\n',tf);

%% ------------------------------------------------------------
% 1. Fault-class mapping
% ------------------------------------------------------------

switch cls

    case "AG"
        faultEnum = 'ee.enum.fault_type_option.ag';
        expectedFamily = "LG";

    case "BG"
        faultEnum = 'ee.enum.fault_type_option.bg';
        expectedFamily = "LG";

    case "CG"
        faultEnum = 'ee.enum.fault_type_option.cg';
        expectedFamily = "LG";

    case "AB"
        faultEnum = 'ee.enum.fault_type_option.ab';
        expectedFamily = "LL";

    case "BC"
        faultEnum = 'ee.enum.fault_type_option.bc';
        expectedFamily = "LL";

    case "CA"
        faultEnum = 'ee.enum.fault_type_option.ca';
        expectedFamily = "LL";

    case "ABG"
        faultEnum = 'ee.enum.fault_type_option.abg';
        expectedFamily = "LLG";

    case "BCG"
        faultEnum = 'ee.enum.fault_type_option.bcg';
        expectedFamily = "LLG";

    case "CAG"
        faultEnum = 'ee.enum.fault_type_option.cag';
        expectedFamily = "LLG";

    case "ABC"
        faultEnum = 'ee.enum.fault_type_option.abc';
        expectedFamily = "LLL";

    otherwise
        error('Unsupported fault class: %s',cls);
end

assert(fam==expectedFamily, ...
    'Class/family mismatch for %s.',eventID);

%% ------------------------------------------------------------
% 2. Five physical fault blocks
% ------------------------------------------------------------

faultBuses = [4 10 18 25 33];

faultBlocks = {
    [model '/ThreePhaseFault2']
    [model '/ThreePhaseFault1']
    [model '/ThreePhaseFault']
    [model '/ThreePhaseFault3']
    [model '/ThreePhaseFault4']
};

selected = find(faultBuses==bus);

assert(numel(selected)==1, ...
    'Unsupported or ambiguous fault bus.');

selectedBlock = faultBlocks{selected};

%% ------------------------------------------------------------
% 3. Reset all five blocks
% ------------------------------------------------------------

for k = 1:5

    set_param(faultBlocks{k}, ...
        'fault_type_option', ...
        'ee.enum.fault_type_option.none');

    set_param(faultBlocks{k}, ...
        'R_pn_fault','0.999');

    set_param(faultBlocks{k}, ...
        'R_ng_fault','0.001');

    set_param(faultBlocks{k}, ...
        'Commented','on');

end

%% ------------------------------------------------------------
% 4. Configure selected block
% ------------------------------------------------------------

set_param(selectedBlock,'Commented','off');

set_param(selectedBlock, ...
    'fault_type_option',faultEnum);

set_param(selectedBlock, ...
    'R_pn_fault',num2str(Rf,'%.15g'));

% Frozen convention:
% Rf = Rpn.
% Rng = 0.001 ohm.
set_param(selectedBlock, ...
    'R_ng_fault','0.001');

set_param(selectedBlock, ...
    'enable_temporal_fault', ...
    'ee.enum.enable.yes');

set_param(selectedBlock, ...
    'fault_start_time', ...
    num2str(tf,'%.15g'));

set_param(selectedBlock, ...
    'fault_duration','inf');

%% ------------------------------------------------------------
% 5. Locate 32 load blocks
% ------------------------------------------------------------

allBlocks = find_system(model, ...
    'LookUnderMasks','all', ...
    'FollowLinks','on', ...
    'Type','Block');

loadBlocks = {};
loadBuses = [];

for k = 1:numel(allBlocks)

    blk = allBlocks{k};

    try
        dp = get_param(blk,'DialogParameters');

        if isfield(dp,'P') && isfield(dp,'Qpos')

            tok = regexp(blk, ...
                '/Bus_(\d+)/','tokens','once');

            if ~isempty(tok)

                loadBus = str2double(tok{1});

                if loadBus >= 2 && loadBus <= 33

                    loadBlocks{end+1,1} = blk;
                    loadBuses(end+1,1) = loadBus;

                end
            end
        end
    catch
    end
end

assert(numel(loadBlocks)==32, ...
    'Expected exactly 32 load blocks.');

assert(numel(unique(loadBuses))==32, ...
    'Load-bus mapping is not unique.');

%% ------------------------------------------------------------
% 6. Frozen nominal load table
% Bus   P(kW)   Q(kvar)
% ------------------------------------------------------------

loadTable = [
 2 100 60
 3 90 40
 4 120 80
 5 60 30
 6 60 20
 7 200 100
 8 200 100
 9 60 20
10 60 20
11 45 30
12 60 35
13 60 35
14 120 80
15 60 10
16 60 20
17 60 20
18 90 40
19 90 40
20 90 40
21 90 40
22 90 40
23 90 50
24 420 200
25 420 200
26 60 25
27 60 25
28 60 20
29 120 70
30 200 600
31 150 70
32 210 100
33 60 40
];

%% ------------------------------------------------------------
% 7. Scale every load FROM NOMINAL
% ------------------------------------------------------------

for k = 1:numel(loadBlocks)

    loadBus = loadBuses(k);

    row = find(loadTable(:,1)==loadBus,1);

    assert(~isempty(row), ...
        'Nominal load missing for Bus %d.',loadBus);

    Pnew = loadTable(row,2)*1000*lambda;
    Qnew = loadTable(row,3)*1000*lambda;

    set_param(loadBlocks{k}, ...
        'P',num2str(Pnew,'%.15g'));

    set_param(loadBlocks{k}, ...
        'Qpos',num2str(Qnew,'%.15g'));

end

%% ------------------------------------------------------------
% 8. Audit load totals
% ------------------------------------------------------------

Pread = 0;
Qread = 0;

for k = 1:numel(loadBlocks)

    Pread = Pread + ...
        str2double(get_param(loadBlocks{k},'P'));

    Qread = Qread + ...
        str2double(get_param(loadBlocks{k},'Qpos'));

end

Pexpected = 3715*lambda*1000;
Qexpected = 2300*lambda*1000;

assert(abs(Pread-Pexpected)<1e-3, ...
    'Total P audit failed.');

assert(abs(Qread-Qexpected)<1e-3, ...
    'Total Q audit failed.');

%% ------------------------------------------------------------
% 9. Audit fault configuration
% ------------------------------------------------------------

activeCount = 0;

for k = 1:5

    if strcmp( ...
            get_param(faultBlocks{k},'Commented'),'off')

        activeCount = activeCount + 1;

    end
end

assert(activeCount==1, ...
    'Exactly one fault block must participate.');

assert(strcmp( ...
    get_param(selectedBlock,'fault_type_option'), ...
    faultEnum), ...
    'Fault-class readback failed.');

assert(abs(str2double( ...
    get_param(selectedBlock,'R_pn_fault'))-Rf)<1e-10, ...
    'Rpn readback failed.');

assert(abs(str2double( ...
    get_param(selectedBlock,'R_ng_fault'))-0.001)<1e-12, ...
    'Rng readback failed.');

assert(abs(str2double( ...
    get_param(selectedBlock,'fault_start_time'))-tf)<1e-12, ...
    'Fault-time readback failed.');

%% ------------------------------------------------------------
% 10. Frozen breaker topology
% ------------------------------------------------------------

CBstate = [ones(1,32) zeros(1,5)];

siminCB = [
    0.0 CBstate
    0.2 CBstate
];

assignin('base','siminCB',siminCB);

%% ------------------------------------------------------------
% 11. Return audit information
% ------------------------------------------------------------

info = struct;

info.event_id = eventID;
info.fault_class = cls;
info.fault_family = fam;
info.fault_bus = bus;

info.fault_enum = string(faultEnum);
info.selected_block = string(selectedBlock);

info.R_pn_fault_ohm = Rf;
info.R_ng_fault_ohm = 0.001;

info.load_level = lambda;

info.total_P_kW = Pread/1000;
info.total_Q_kvar = Qread/1000;

info.fault_start_requested_s = tf;

info.active_fault_blocks = activeCount;

fprintf('\nCONFIGURATION AUDIT\n');
fprintf('------------------------------------------------------------\n');

fprintf('Selected block : %s\n',selectedBlock);
fprintf('Fault enum     : %s\n',faultEnum);
fprintf('Rpn            : %.12f ohm\n',Rf);
fprintf('Rng            : %.6f ohm\n',0.001);
fprintf('Total P        : %.6f kW\n',Pread/1000);
fprintf('Total Q        : %.6f kvar\n',Qread/1000);
fprintf('Active blocks  : %d\n',activeCount);

fprintf('\nPASS: %s configured successfully.\n',eventID);
fprintf('NO SIMULATION PERFORMED.\n');
fprintf('NO FILE SAVED.\n');

end
