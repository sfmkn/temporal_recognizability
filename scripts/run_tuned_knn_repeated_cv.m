%% ============================================================
% TUNED KNN — REPEATED 5x5 CROSS-VALIDATION
% ALL 20 TEMPORAL WINDOWS
%
% Frozen KNN after 29 tuning evaluations:
%   k = 1
%   Distance = Chebychev
%   Weight = inverse
%
% Protocol:
%   Development pool = train + validation = 1700 events
%   Locked test       = 300 events — NEVER USED
%
%   5-fold CV x 5 repeats = 25 evaluations/window
%
% IMPORTANT:
%   - Uses EXISTING frozen CV folds
%   - Uses same 48 features as SVM
%   - Standardization fitted inside each CV training fold
%   - No test-set access
% ============================================================

clear;
clc;

fprintf('\n====================================================\n');
fprintf(' TUNED KNN — REPEATED 5x5 CV, ALL 20 WINDOWS\n');
fprintf('====================================================\n\n');


%% ============================================================
% STEP 1 — PATHS
% ============================================================

rootDir = '/MATLAB Drive/Temporal_Recognizability_Dataset';

featureDir = fullfile( ...
    rootDir, ...
    'Feature_Dataset_V1');

foldFile = fullfile( ...
    rootDir, ...
    'Results', ...
    'CrossValidation', ...
    'TR_REPEATED_CV_FOLDS_V1.mat');

outputDir = fullfile( ...
    rootDir, ...
    'Results', ...
    'CrossValidation');

assert(isfolder(featureDir), ...
    'Feature directory not found.');

assert(isfile(foldFile), ...
    'Frozen CV fold file not found:\n%s', foldFile);

fprintf('Feature directory found.\n');
fprintf('Frozen CV fold file found.\n\n');


%% ============================================================
% STEP 2 — LOAD AND INSPECT FROZEN CV FOLD FILE
%
% We deliberately inspect before assuming its variable name.
% ============================================================

F = load(foldFile);

fprintf('Variables found in frozen fold file:\n');
disp(fieldnames(F));


%% ============================================================
% STEP 3 — IDENTIFY FOLD VARIABLE
%
% This section accepts several common names.
% If none match, it STOPS SAFELY rather than inventing folds.
% ============================================================

if isfield(F,'folds')

    frozenFolds = F.folds;

elseif isfield(F,'cvFolds')

    frozenFolds = F.cvFolds;

elseif isfield(F,'CVFolds')

    frozenFolds = F.CVFolds;

elseif isfield(F,'foldAssignments')

    frozenFolds = F.foldAssignments;

elseif isfield(F,'fold_indices')

    frozenFolds = F.fold_indices;

else

    fprintf('\nSTOPPING SAFELY.\n');
    fprintf('The fold-file variable structure is not one of the expected names.\n');
    fprintf('Do NOT generate new folds.\n');
    fprintf('Send me the variable listing printed above.\n');

    return;
end


fprintf('Frozen fold variable identified.\n');
fprintf('Class: %s\n', class(frozenFolds));
fprintf('Size:  ');
disp(size(frozenFolds));


%% ============================================================
% STEP 4 — EXPECTED FOLD FORMAT
%
% For this script we expect a 1700 x 5 matrix:
%
%   rows    = development events
%   columns = repeat 1 ... repeat 5
%   values  = fold number 1 ... 5
%
% If the stored object has another format, STOP.
% ============================================================

if ~(isnumeric(frozenFolds) || islogical(frozenFolds))

    fprintf('\nSTOPPING SAFELY.\n');
    fprintf('Frozen folds are not stored as a numeric assignment matrix.\n');
    fprintf('Do NOT create new folds.\n');
    fprintf('Send me the class and size printed above.\n');

    return;
end


if ~isequal(size(frozenFolds), [1700 5])

    fprintf('\nSTOPPING SAFELY.\n');
    fprintf('Expected frozen fold matrix size = 1700 x 5.\n');
    fprintf('Actual size shown above.\n');
    fprintf('Do NOT create or alter folds.\n');

    return;
end


% Verify fold numbers
assert(all(ismember(unique(frozenFolds(:)),1:5)), ...
    'Frozen fold assignments must contain only fold IDs 1...5.');

fprintf('Frozen fold structure check: PASS\n');
fprintf('Same 5 folds x 5 repeats will be reused.\n\n');


%% ============================================================
% STEP 5 — FREEZE KNN CONFIGURATION
% ============================================================

KNN_K = 1;
KNN_DISTANCE = 'chebychev';
KNN_WEIGHT = 'inverse';

fprintf('Frozen tuned KNN:\n');
fprintf('  k        = %d\n', KNN_K);
fprintf('  Distance = %s\n', KNN_DISTANCE);
fprintf('  Weight   = %s\n\n', KNN_WEIGHT);


%% ============================================================
% STEP 6 — STORAGE
% ============================================================

nWindows = 20;
nRepeats = 5;
nFolds   = 5;
nRuns    = nRepeats * nFolds;

accuracyAll = zeros(nWindows,nRuns);
macroF1All  = zeros(nWindows,nRuns);

meanAccuracy = zeros(nWindows,1);
stdAccuracy  = zeros(nWindows,1);

meanMacroF1 = zeros(nWindows,1);
stdMacroF1  = zeros(nWindows,1);

windowNames = strings(nWindows,1);


%% ============================================================
% STEP 7 — PROCESS ALL 20 WINDOWS
% ============================================================

for w = 1:nWindows

    fprintf('\n====================================================\n');
    fprintf(' WINDOW W%02d / W20\n', w);
    fprintf('====================================================\n');


    %% --------------------------------------------------------
    % Load feature file
    % ---------------------------------------------------------

    featureFile = fullfile( ...
        featureDir, ...
        sprintf('TR_FEATURES_V1_W%02d.mat',w));

    assert(isfile(featureFile), ...
        'Missing feature file: %s', featureFile);

    S = load(featureFile);

    X = S.X;
    Y = categorical(S.fault_classes);
    splitLabels = string(S.splits);


    %% --------------------------------------------------------
    % Safety checks
    % ---------------------------------------------------------

    assert(size(X,1) == 2000);
    assert(size(X,2) == 48);
    assert(numel(Y) == 2000);
    assert(numel(splitLabels) == 2000);


    %% --------------------------------------------------------
    % Development pool ONLY
    %
    % Train + validation = 1700
    % Test remains excluded.
    % ---------------------------------------------------------

    devIdx = find( ...
        splitLabels == "train" | ...
        splitLabels == "validation");

    testIdx = find(splitLabels == "test");

    assert(numel(devIdx) == 1700, ...
        'Expected 1700 development events.');

    assert(numel(testIdx) == 300, ...
        'Expected 300 locked test events.');

    Xdev = X(devIdx,:);
    Ydev = Y(devIdx);

    % No Xtest or Ytest is created.


    %% --------------------------------------------------------
    % Window label
    % ---------------------------------------------------------

    if isfield(S,'window_metadata')

        try
            if isfield(S.window_metadata,'label')
                windowNames(w) = string(S.window_metadata.label);
            else
                windowNames(w) = sprintf("W%02d",w);
            end
        catch
            windowNames(w) = sprintf("W%02d",w);
        end

    else
        windowNames(w) = sprintf("W%02d",w);
    end


    %% --------------------------------------------------------
    % Repeated 5-fold CV
    % ---------------------------------------------------------

    runCounter = 0;

    for r = 1:nRepeats

        fprintf('Repeat %d/5\n',r);

        foldAssignment = frozenFolds(:,r);

        for f = 1:nFolds

            runCounter = runCounter + 1;

            valMask   = (foldAssignment == f);
            trainMask = ~valMask;


            %% ------------------------------------------------
            % Fold-specific train/validation data
            % -------------------------------------------------

            Xtrain = Xdev(trainMask,:);
            Ytrain = Ydev(trainMask);

            Xval = Xdev(valMask,:);
            Yval = Ydev(valMask);


            %% ------------------------------------------------
            % TRAINING-FOLD-ONLY STANDARDIZATION
            % -------------------------------------------------

            mu = mean(Xtrain,1);
            sigma = std(Xtrain,0,1);

            nearZero = sigma < 1e-8;

            sigma(nearZero) = 1;

            XtrainZ = (Xtrain - mu) ./ sigma;
            XvalZ   = (Xval   - mu) ./ sigma;

            XtrainZ(:,nearZero) = 0;
            XvalZ(:,nearZero)   = 0;


            %% ------------------------------------------------
            % Train frozen tuned KNN
            % -------------------------------------------------

            mdl = fitcknn( ...
                XtrainZ, ...
                Ytrain, ...
                'NumNeighbors', KNN_K, ...
                'Distance', KNN_DISTANCE, ...
                'DistanceWeight', KNN_WEIGHT, ...
                'Standardize', false);


            %% ------------------------------------------------
            % Predict held-out CV fold
            % -------------------------------------------------

            Ypred = predict(mdl,XvalZ);


            %% ------------------------------------------------
            % Accuracy
            % -------------------------------------------------

            acc = mean(Ypred == Yval);


            %% ------------------------------------------------
            % Macro-F1
            % -------------------------------------------------

            classNames = categories(Ydev);

            classF1 = zeros(numel(classNames),1);

            for c = 1:numel(classNames)

                className = classNames{c};

                TP = sum( ...
                    (Ypred == className) & ...
                    (Yval  == className));

                FP = sum( ...
                    (Ypred == className) & ...
                    (Yval  ~= className));

                FN = sum( ...
                    (Ypred ~= className) & ...
                    (Yval  == className));


                if (TP + FP) == 0
                    precision = 0;
                else
                    precision = TP/(TP+FP);
                end


                if (TP + FN) == 0
                    recall = 0;
                else
                    recall = TP/(TP+FN);
                end


                if (precision + recall) == 0
                    classF1(c) = 0;
                else
                    classF1(c) = ...
                        2*precision*recall / ...
                        (precision+recall);
                end

            end

            mf1 = mean(classF1);


            %% ------------------------------------------------
            % Store
            % -------------------------------------------------

            accuracyAll(w,runCounter) = acc;
            macroF1All(w,runCounter)  = mf1;

        end
    end


    %% --------------------------------------------------------
    % Mean and empirical sample SD over 25 evaluations
    % ---------------------------------------------------------

    meanAccuracy(w) = mean(accuracyAll(w,:));
    stdAccuracy(w)  = std(accuracyAll(w,:),0);

    meanMacroF1(w) = mean(macroF1All(w,:));
    stdMacroF1(w)  = std(macroF1All(w,:),0);


    fprintf('\nW%02d COMPLETE\n',w);

    fprintf('Accuracy = %.2f%% +/- %.2f%%\n', ...
        100*meanAccuracy(w), ...
        100*stdAccuracy(w));

    fprintf('Macro-F1 = %.4f +/- %.4f\n', ...
        meanMacroF1(w), ...
        stdMacroF1(w));

end


%% ============================================================
% STEP 8 — SUMMARY TABLE
% ============================================================

Window = (1:nWindows)';

summaryTable = table( ...
    Window, ...
    windowNames, ...
    meanAccuracy, ...
    stdAccuracy, ...
    meanMacroF1, ...
    stdMacroF1, ...
    'VariableNames', ...
    {'Window','WindowLabel', ...
     'MeanAccuracy','SDAccuracy', ...
     'MeanMacroF1','SDMacroF1'});


fprintf('\n\n====================================================\n');
fprintf(' TUNED KNN — FINAL REPEATED-CV SUMMARY\n');
fprintf('====================================================\n\n');

disp(summaryTable);


%% ============================================================
% STEP 9 — CHECK TEMPORAL RECOGNIZABILITY CRITERION
%
% Criterion:
% Earliest window where BOTH
%
%   Mean Accuracy >= 0.90
%   Mean Macro-F1 >= 0.90
%
% AND both remain >= 0.90 at immediately following window.
% ============================================================

criterionPass = ...
    (meanAccuracy >= 0.90) & ...
    (meanMacroF1 >= 0.90);

recognizableWindow = NaN;

for w = 1:(nWindows-1)

    if criterionPass(w) && criterionPass(w+1)

        recognizableWindow = w;
        break;

    end
end


fprintf('\n====================================================\n');
fprintf(' TEMPORAL RECOGNIZABILITY CHECK\n');
fprintf('====================================================\n\n');

if isnan(recognizableWindow)

    fprintf(['Tuned KNN does NOT satisfy the frozen ', ...
             '0.90/0.90 persistence criterion within W01-W20.\n']);

else

    fprintf('Earliest qualifying window = W%02d\n', ...
        recognizableWindow);

    fprintf('Next window W%02d also passes.\n', ...
        recognizableWindow+1);

end


%% ============================================================
% STEP 10 — SAVE NEW RESULTS
%
% IMPORTANT:
% New filenames prevent overwriting old Hojabri-style results.
% ============================================================

saveFile = fullfile( ...
    outputDir, ...
    'TunedKNN_RepeatedCV_29Budget_V1.mat');

csvFile = fullfile( ...
    outputDir, ...
    'TunedKNN_RepeatedCV_29Budget_Summary_V1.csv');


save( ...
    saveFile, ...
    'summaryTable', ...
    'accuracyAll', ...
    'macroF1All', ...
    'meanAccuracy', ...
    'stdAccuracy', ...
    'meanMacroF1', ...
    'stdMacroF1', ...
    'criterionPass', ...
    'recognizableWindow', ...
    'KNN_K', ...
    'KNN_DISTANCE', ...
    'KNN_WEIGHT');


writetable(summaryTable,csvFile);


fprintf('\nSaved WITHOUT overwriting previous baseline results:\n');
fprintf('%s\n',saveFile);
fprintf('%s\n',csvFile);


fprintf('\n====================================================\n');
fprintf(' TUNED KNN REPEATED CV COMPLETE\n');
fprintf('====================================================\n');

fprintf('\nSTOP HERE.\n');
fprintf('Locked test set was NOT used.\n');
fprintf('Do NOT open the test set yet.\n');