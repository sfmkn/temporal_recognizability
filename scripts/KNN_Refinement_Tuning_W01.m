%% ============================================================
% KNN REFINEMENT HYPERPARAMETER TUNING — W01 (T/128)
%
% Broad-search winner:
%   k = 3
%   Distance = Euclidean
%   Weight = inverse
%
% Broad search budget      = 20 configurations
% Refinement budget        =  9 configurations
% TOTAL KNN TUNING BUDGET  = 29 configurations
%
% IMPORTANT:
%   - Frozen 70/15/15 split preserved
%   - Training = 1400
%   - Validation = 300
%   - Test = 300, LOCKED AND NEVER USED
%   - Standardization learned from TRAINING ONLY
%   - Primary selection metric = Macro-F1
% ============================================================

clear;
clc;

fprintf('\n===============================================\n');
fprintf(' KNN REFINEMENT TUNING — W01 (T/128)\n');
fprintf('===============================================\n\n');


%% ============================================================
% STEP 1 — LOAD FROZEN W01 FEATURE DATA
% ============================================================

dataFile = fullfile( ...
    '/MATLAB Drive/Temporal_Recognizability_Dataset', ...
    'Feature_Dataset_V1', ...
    'TR_FEATURES_V1_W01.mat');

assert(isfile(dataFile), ...
    'Feature file not found:\n%s', dataFile);

S = load(dataFile);

X = S.X;
Y = categorical(S.fault_classes);
splitLabels = string(S.splits);

fprintf('Dataset loaded successfully.\n');
fprintf('Feature matrix: %d x %d\n', size(X,1), size(X,2));
fprintf('Labels:         %d\n\n', numel(Y));


%% ============================================================
% STEP 2 — DATASET SAFETY CHECK
% ============================================================

assert(size(X,1) == 2000, ...
    'Expected 2000 events.');

assert(size(X,2) == 48, ...
    'Expected 48 features.');

assert(numel(Y) == 2000, ...
    'Expected 2000 labels.');

assert(numel(splitLabels) == 2000, ...
    'Expected 2000 split labels.');

fprintf('Dataset integrity check: PASS\n\n');


%% ============================================================
% STEP 3 — RECOVER FROZEN SPLIT
% ============================================================

trainIdx = find(splitLabels == "train");
valIdx   = find(splitLabels == "validation");
testIdx  = find(splitLabels == "test");

fprintf('Frozen split:\n');
fprintf('  Training   = %d\n', numel(trainIdx));
fprintf('  Validation = %d\n', numel(valIdx));
fprintf('  Test       = %d  <-- LOCKED\n\n', numel(testIdx));

assert(numel(trainIdx) == 1400);
assert(numel(valIdx)   == 300);
assert(numel(testIdx)  == 300);

allIdx = [trainIdx; valIdx; testIdx];

assert(numel(unique(allIdx)) == 2000, ...
    'Split overlap or missing events detected.');

fprintf('Split integrity check: PASS\n');
fprintf('Locked test set will NOT be used.\n\n');


%% ============================================================
% STEP 4 — EXTRACT TRAINING + VALIDATION ONLY
% ============================================================

Xtrain = X(trainIdx,:);
Ytrain = Y(trainIdx);

Xval = X(valIdx,:);
Yval = Y(valIdx);

% Deliberately DO NOT create Xtest or Ytest.


%% ============================================================
% STEP 5 — TRAINING-ONLY STANDARDIZATION
% ============================================================

mu = mean(Xtrain,1);
sigma = std(Xtrain,0,1);

sigmaTolerance = 1e-8;

nearZero = sigma < sigmaTolerance;

sigma(nearZero) = 1;

XtrainZ = (Xtrain - mu) ./ sigma;
XvalZ   = (Xval   - mu) ./ sigma;

XtrainZ(:,nearZero) = 0;
XvalZ(:,nearZero)   = 0;

fprintf('Training-only standardization: PASS\n');
fprintf('Near-zero variance features: %d\n\n', sum(nearZero));


%% ============================================================
% STEP 6 — FREEZE THE 9 REFINEMENT CONFIGURATIONS
%
% Broad winner was k = 3, so examine the immediate
% neighborhood around k = 3:
%
%       k = 1, 2, 4
%
% Three distance geometries:
%
%       Euclidean
%       Cityblock (Manhattan)
%       Chebychev
%
% Inverse weighting is frozen because it clearly outperformed
% equal weighting during the broad search.
%
% 3 k-values x 3 distances = 9 configurations.
% ============================================================

kValues = [1 2 4];

distanceNames = { ...
    'euclidean', ...
    'cityblock', ...
    'chebychev'};

weightName = 'inverse';

nConfigs = numel(kValues) * numel(distanceNames);

assert(nConfigs == 9, ...
    'Refinement tuning budget must equal exactly 9.');

fprintf('Refinement configurations are now FROZEN.\n');
fprintf('k values: 1, 2, 4\n');
fprintf('Distances: Euclidean, Cityblock, Chebychev\n');
fprintf('Weighting: inverse\n');
fprintf('Refinement budget = %d configurations\n', nConfigs);
fprintf('Total KNN tuning budget = 20 + 9 = 29\n\n');


%% ============================================================
% STEP 7 — RESULT STORAGE
% ============================================================

Config      = zeros(nConfigs,1);
K           = zeros(nConfigs,1);
Distance    = strings(nConfigs,1);
Weight      = strings(nConfigs,1);
ValAccuracy = zeros(nConfigs,1);
ValMacroF1  = zeros(nConfigs,1);

counter = 0;


%% ============================================================
% STEP 8 — RUN THE 9 REFINEMENT CONFIGURATIONS
% ============================================================

fprintf('===============================================\n');
fprintf(' BEGINNING 9-CONFIGURATION REFINEMENT\n');
fprintf('===============================================\n\n');

for k = kValues

    for j = 1:numel(distanceNames)

        counter = counter + 1;

        thisDistance = distanceNames{j};

        fprintf('Refinement %02d/09\n', counter);
        fprintf('  k        = %d\n', k);
        fprintf('  Distance = %s\n', thisDistance);
        fprintf('  Weight   = %s\n', weightName);


        %% ----------------------------------------------------
        % Train KNN
        % -----------------------------------------------------

        mdl = fitcknn( ...
            XtrainZ, ...
            Ytrain, ...
            'NumNeighbors', k, ...
            'Distance', thisDistance, ...
            'DistanceWeight', weightName, ...
            'Standardize', false);


        %% ----------------------------------------------------
        % Predict VALIDATION set only
        % -----------------------------------------------------

        Ypred = predict(mdl, XvalZ);


        %% ----------------------------------------------------
        % Accuracy
        % -----------------------------------------------------

        accuracy = mean(Ypred == Yval);


        %% ----------------------------------------------------
        % Macro-F1
        % -----------------------------------------------------

        classNames = categories(Y);

        classF1 = zeros(numel(classNames),1);

        for c = 1:numel(classNames)

            className = classNames{c};

            TP = sum((Ypred == className) & ...
                     (Yval  == className));

            FP = sum((Ypred == className) & ...
                     (Yval  ~= className));

            FN = sum((Ypred ~= className) & ...
                     (Yval  == className));


            if (TP + FP) == 0
                precision = 0;
            else
                precision = TP / (TP + FP);
            end


            if (TP + FN) == 0
                recall = 0;
            else
                recall = TP / (TP + FN);
            end


            if (precision + recall) == 0
                classF1(c) = 0;
            else
                classF1(c) = ...
                    2 * precision * recall / ...
                    (precision + recall);
            end

        end

        macroF1 = mean(classF1);


        %% ----------------------------------------------------
        % Store
        % -----------------------------------------------------

        Config(counter)      = counter;
        K(counter)           = k;
        Distance(counter)    = string(thisDistance);
        Weight(counter)      = string(weightName);
        ValAccuracy(counter) = accuracy;
        ValMacroF1(counter)  = macroF1;


        fprintf('  Accuracy = %.4f (%.2f%%)\n', ...
            accuracy, accuracy*100);

        fprintf('  Macro-F1 = %.4f\n\n', macroF1);

    end

end


%% ============================================================
% STEP 9 — BUILD REFINEMENT RESULTS TABLE
% ============================================================

refinementResults = table( ...
    Config, ...
    K, ...
    Distance, ...
    Weight, ...
    ValAccuracy, ...
    ValMacroF1);


fprintf('\n===============================================\n');
fprintf(' ALL 9 REFINEMENT RESULTS\n');
fprintf('===============================================\n\n');

disp(refinementResults);


%% ============================================================
% STEP 10 — RANK REFINEMENT RESULTS
%
% Primary criterion:
%       Macro-F1
%
% Tie breaker:
%       Accuracy
% ============================================================

rankedRefinement = sortrows( ...
    refinementResults, ...
    {'ValMacroF1','ValAccuracy'}, ...
    {'descend','descend'});

bestRefinement = rankedRefinement(1,:);

fprintf('\n===============================================\n');
fprintf(' RANKED REFINEMENT RESULTS\n');
fprintf('===============================================\n\n');

disp(rankedRefinement);


%% ============================================================
% STEP 11 — LOAD THE PREVIOUS 20 BROAD RESULTS
% ============================================================

broadFile = fullfile( ...
    '/MATLAB Drive/Temporal_Recognizability_Dataset', ...
    'Results', ...
    'HyperparameterTuning', ...
    'KNN_BroadTuning_W01_V1.mat');

assert(isfile(broadFile), ...
    'Previous broad-search result file not found.');

B = load(broadFile);

broadResults = B.results;

fprintf('\nPrevious 20 broad-search results loaded.\n');


%% ============================================================
% STEP 12 — COMBINE ALL 29 EVALUATIONS
% ============================================================

% Give each configuration its tuning stage
broadStage = repmat("Broad", height(broadResults), 1);
refineStage = repmat("Refinement", height(refinementResults), 1);

broadAll = table( ...
    broadStage, ...
    broadResults.K, ...
    broadResults.Distance, ...
    broadResults.Weight, ...
    broadResults.ValAccuracy, ...
    broadResults.ValMacroF1, ...
    'VariableNames', ...
    {'Stage','K','Distance','Weight', ...
     'ValAccuracy','ValMacroF1'});

refineAll = table( ...
    refineStage, ...
    refinementResults.K, ...
    refinementResults.Distance, ...
    refinementResults.Weight, ...
    refinementResults.ValAccuracy, ...
    refinementResults.ValMacroF1, ...
    'VariableNames', ...
    {'Stage','K','Distance','Weight', ...
     'ValAccuracy','ValMacroF1'});

all29Results = [broadAll; refineAll];

rankedAll29 = sortrows( ...
    all29Results, ...
    {'ValMacroF1','ValAccuracy'}, ...
    {'descend','descend'});


%% ============================================================
% STEP 13 — FINAL WINNER FROM ALL 29
% ============================================================

bestOverall = rankedAll29(1,:);

fprintf('\n===============================================\n');
fprintf(' FINAL KNN TUNING RESULT — ALL 29\n');
fprintf('===============================================\n\n');

disp(rankedAll29);

fprintf('\n===============================================\n');
fprintf(' BEST KNN CONFIGURATION FROM 29 EVALUATIONS\n');
fprintf('===============================================\n\n');

disp(bestOverall);

fprintf('Stage           = %s\n', bestOverall.Stage);
fprintf('k               = %d\n', bestOverall.K);
fprintf('Distance        = %s\n', bestOverall.Distance);
fprintf('Weighting       = %s\n', bestOverall.Weight);
fprintf('Validation Acc  = %.4f (%.2f%%)\n', ...
    bestOverall.ValAccuracy, ...
    100*bestOverall.ValAccuracy);
fprintf('Validation F1   = %.4f\n', ...
    bestOverall.ValMacroF1);


%% ============================================================
% STEP 14 — SAVE EVERYTHING
% ============================================================

outputDir = fullfile( ...
    '/MATLAB Drive/Temporal_Recognizability_Dataset', ...
    'Results', ...
    'HyperparameterTuning');

saveFile = fullfile( ...
    outputDir, ...
    'KNN_29Config_Tuning_W01_V1.mat');

csvFile = fullfile( ...
    outputDir, ...
    'KNN_29Config_Tuning_W01_V1.csv');


save( ...
    saveFile, ...
    'refinementResults', ...
    'rankedRefinement', ...
    'all29Results', ...
    'rankedAll29', ...
    'bestOverall', ...
    'kValues', ...
    'distanceNames', ...
    'weightName', ...
    'mu', ...
    'sigma', ...
    'nearZero');


writetable(rankedAll29, csvFile);


fprintf('\nResults saved to:\n');
fprintf('%s\n', saveFile);
fprintf('%s\n', csvFile);


%% ============================================================
% FINAL STOP
% ============================================================

fprintf('\n===============================================\n');
fprintf(' KNN TUNING COMPLETE: 20 + 9 = 29\n');
fprintf('===============================================\n');

fprintf('\nSTOP HERE.\n');
fprintf('The locked test set has NOT been used.\n');
fprintf('Do NOT tune KNN any further.\n');