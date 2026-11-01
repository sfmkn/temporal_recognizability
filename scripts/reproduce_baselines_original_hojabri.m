%% ============================================================
% STEP 36F: REPRODUCE ALL STAGE-3 BASELINES
%
% Models:
%   B1 = RBF-SVM
%   B2 = Hojabri-style KNN
%   B3 = Uniform-random trivial baseline
%
% Evaluation:
%   20 temporal windows
%   5-fold CV x 5 repeats = 25 evaluations/window
%   Frozen event-level folds
%   Fold-specific training-only standardization
%
% Metrics:
%   Accuracy
%   Macro-F1
%
% IMPORTANT:
%   The locked 300-event test set is NOT used.
%% ============================================================

clear; clc;

fprintf('\n============================================\n');
fprintf('TEMPORAL RECOGNIZABILITY\n');
fprintf('STAGE-3 BASELINE REPRODUCTION\n');
fprintf('============================================\n');

%% ------------------------------------------------------------
% 1. Paths
%% ------------------------------------------------------------

baseDir = '/MATLAB Drive/Temporal_Recognizability_Dataset';

featureDir = fullfile(baseDir,'Feature_Dataset_V1');

foldFile = fullfile( ...
    baseDir,'Results','CrossValidation', ...
    'TR_REPEATED_CV_FOLDS_V1.mat');

outputDir = fullfile( ...
    baseDir,'Results','Reproduction');

if ~isfolder(outputDir)
    mkdir(outputDir);
end

%% ------------------------------------------------------------
% 2. Frozen experimental settings
%% ------------------------------------------------------------

numWindows = 20;

windowNames = { ...
    'T/128','T/64','T/32','T/16','T/8', ...
    'T/4','T/2','T','9T/8','10T/8', ...
    '11T/8','12T/8','13T/8','14T/8','15T/8', ...
    '2T','2.25T','2.5T','2.75T','3T'};

sigmaTolerance = 1e-8;

% Frozen SVM
svmC  = 300;
svmKS = 10;

% Frozen KNN
knnK = 5;

% Frozen trivial-baseline RNG
rng(750,'twister');

%% ------------------------------------------------------------
% 3. Load frozen repeated-CV assignments
%% ------------------------------------------------------------

F = load(foldFile);

numFolds   = F.numFolds;
numRepeats = F.numRepeats;

devEventIDs = string(F.devEventIDs);
devLabels   = categorical(F.devLabels);

foldAssignments = F.foldAssignments;

classNames = string(F.classNames);

numClasses = numel(classNames);

fprintf('\nDevelopment events : %d\n',numel(devEventIDs));
fprintf('Classes            : %d\n',numClasses);
fprintf('Folds              : %d\n',numFolds);
fprintf('Repeats            : %d\n',numRepeats);
fprintf('Evaluations/window : %d\n',numFolds*numRepeats);

%% ------------------------------------------------------------
% 4. Allocate result arrays
%% ------------------------------------------------------------

numEvaluations = numFolds*numRepeats;

svmAccuracyAll = zeros(numWindows,numEvaluations);
svmF1All       = zeros(numWindows,numEvaluations);

knnAccuracyAll = zeros(numWindows,numEvaluations);
knnF1All       = zeros(numWindows,numEvaluations);

randomAccuracyAll = zeros(numWindows,numEvaluations);
randomF1All       = zeros(numWindows,numEvaluations);

%% ------------------------------------------------------------
% 5. Loop through temporal windows
%% ------------------------------------------------------------

for w = 1:numWindows

    fprintf('\n============================================\n');
    fprintf('WINDOW %02d/%02d : %s\n', ...
        w,numWindows,windowNames{w});
    fprintf('============================================\n');

    featureFile = fullfile( ...
        featureDir, ...
        sprintf('TR_FEATURES_V1_W%02d.mat',w));

    D = load(featureFile, ...
        'X','event_ids','fault_classes','splits');

    Xall = D.X;
    eventIDs = string(D.event_ids);
    labels = categorical(D.fault_classes);

    %% --------------------------------------------------------
    % Match frozen development Event IDs
    %% --------------------------------------------------------

    [tf,loc] = ismember(devEventIDs,eventIDs);

    if ~all(tf)
        error('Not all frozen development Event IDs found in W%02d.',w);
    end

    X = Xall(loc,:);
    Y = labels(loc);

    %% Verify event labels against frozen fold file

    if any(string(Y) ~= string(devLabels))
        error('Label mismatch detected in W%02d.',w);
    end

    fprintf('Event-ID and label audit: PASS\n');

    evalCounter = 0;

    %% --------------------------------------------------------
    % 6. Repeated stratified CV
    %% --------------------------------------------------------

    for r = 1:numRepeats

        for f = 1:numFolds

            evalCounter = evalCounter + 1;

            valMask = foldAssignments(:,r) == f;
            trainMask = ~valMask;

            Xtrain = X(trainMask,:);
            Ytrain = Y(trainMask);

            Xval = X(valMask,:);
            Yval = Y(valMask);

            %% ------------------------------------------------
            % Training-only z-score standardization
            %% ------------------------------------------------

            mu = mean(Xtrain,1);
            sigma = std(Xtrain,0,1);

            nearZero = sigma < sigmaTolerance;

            sigmaSafe = sigma;
            sigmaSafe(nearZero) = 1;

            XtrainZ = (Xtrain - mu) ./ sigmaSafe;
            XvalZ   = (Xval   - mu) ./ sigmaSafe;

            % Explicitly zero near-zero-variance columns
            XtrainZ(:,nearZero) = 0;
            XvalZ(:,nearZero)   = 0;

            %% ------------------------------------------------
            % B1: RBF-SVM multiclass ECOC
            %% ------------------------------------------------

            svmTemplate = templateSVM( ...
                'KernelFunction','rbf', ...
                'BoxConstraint',svmC, ...
                'KernelScale',svmKS, ...
                'Standardize',false);

            svmModel = fitcecoc( ...
                XtrainZ,Ytrain, ...
                'Learners',svmTemplate, ...
                'Coding','onevsone');

            svmPred = predict(svmModel,XvalZ);

            svmAccuracyAll(w,evalCounter) = ...
                mean(svmPred == Yval);

            svmF1All(w,evalCounter) = ...
                macroF1(Yval,svmPred,classNames);

            %% ------------------------------------------------
            % B2: Hojabri-style KNN
            %% ------------------------------------------------

            knnModel = fitcknn( ...
                XtrainZ,Ytrain, ...
                'NumNeighbors',knnK, ...
                'Distance','cityblock', ...
                'DistanceWeight','inverse', ...
                'Standardize',false);

            knnPred = predict(knnModel,XvalZ);

            knnAccuracyAll(w,evalCounter) = ...
                mean(knnPred == Yval);

            knnF1All(w,evalCounter) = ...
                macroF1(Yval,knnPred,classNames);

            %% ------------------------------------------------
            % B3: Uniform-random baseline
            %% ------------------------------------------------

            nVal = sum(valMask);

            randomIndex = randi(numClasses,nVal,1);

            randomPred = categorical( ...
                classNames(randomIndex), ...
                classNames);

            randomAccuracyAll(w,evalCounter) = ...
                mean(randomPred == Yval);

            randomF1All(w,evalCounter) = ...
                macroF1(Yval,randomPred,classNames);

        end
    end

    %% --------------------------------------------------------
    % Window progress summary
    %% --------------------------------------------------------

    fprintf('SVM    : %6.2f +/- %5.2f %%\n', ...
        100*mean(svmAccuracyAll(w,:)), ...
        100*std(svmAccuracyAll(w,:)));

    fprintf('KNN    : %6.2f +/- %5.2f %%\n', ...
        100*mean(knnAccuracyAll(w,:)), ...
        100*std(knnAccuracyAll(w,:)));

    fprintf('Random : %6.2f +/- %5.2f %%\n', ...
        100*mean(randomAccuracyAll(w,:)), ...
        100*std(randomAccuracyAll(w,:)));

end

%% ------------------------------------------------------------
% 7. Build summary table
%% ------------------------------------------------------------

svmAccMean = mean(svmAccuracyAll,2);
svmAccSD   = std(svmAccuracyAll,0,2);
svmF1Mean  = mean(svmF1All,2);
svmF1SD    = std(svmF1All,0,2);

knnAccMean = mean(knnAccuracyAll,2);
knnAccSD   = std(knnAccuracyAll,0,2);
knnF1Mean  = mean(knnF1All,2);
knnF1SD    = std(knnF1All,0,2);

randomAccMean = mean(randomAccuracyAll,2);
randomAccSD   = std(randomAccuracyAll,0,2);
randomF1Mean  = mean(randomF1All,2);
randomF1SD    = std(randomF1All,0,2);

summaryTable = table( ...
    string(windowNames(:)), ...
    svmAccMean,svmAccSD,svmF1Mean,svmF1SD, ...
    knnAccMean,knnAccSD,knnF1Mean,knnF1SD, ...
    randomAccMean,randomAccSD,randomF1Mean,randomF1SD, ...
    'VariableNames',{ ...
    'Window', ...
    'SVM_Accuracy_Mean','SVM_Accuracy_SD', ...
    'SVM_MacroF1_Mean','SVM_MacroF1_SD', ...
    'KNN_Accuracy_Mean','KNN_Accuracy_SD', ...
    'KNN_MacroF1_Mean','KNN_MacroF1_SD', ...
    'Random_Accuracy_Mean','Random_Accuracy_SD', ...
    'Random_MacroF1_Mean','Random_MacroF1_SD'});

%% ------------------------------------------------------------
% 8. Display final baseline table
%% ------------------------------------------------------------

fprintf('\n\n========================================================\n');
fprintf('REPRODUCED STAGE-3 BASELINE RESULTS\n');
fprintf('========================================================\n\n');

for w = 1:numWindows

    fprintf('%-7s | ',windowNames{w});

    fprintf('SVM %5.2f +/- %4.2f %% | ', ...
        100*svmAccMean(w),100*svmAccSD(w));

    fprintf('KNN %5.2f +/- %4.2f %% | ', ...
        100*knnAccMean(w),100*knnAccSD(w));

    fprintf('Random %5.2f +/- %4.2f %%\n', ...
        100*randomAccMean(w),100*randomAccSD(w));
end

%% ------------------------------------------------------------
% 9. Save reproduced results
%% ------------------------------------------------------------

matOutput = fullfile( ...
    outputDir, ...
    'STAGE3_BASELINES_REPRODUCED.mat');

csvOutput = fullfile( ...
    outputDir, ...
    'STAGE3_BASELINES_REPRODUCED.csv');

save(matOutput, ...
    'summaryTable', ...
    'svmAccuracyAll','svmF1All', ...
    'knnAccuracyAll','knnF1All', ...
    'randomAccuracyAll','randomF1All', ...
    'svmC','svmKS','knnK', ...
    'sigmaTolerance','windowNames');

writetable(summaryTable,csvOutput);

fprintf('\nResults saved:\n%s\n%s\n', ...
    matOutput,csvOutput);

fprintf('\nSTEP 36F COMPLETE.\n');


%% ============================================================
% LOCAL FUNCTION: MACRO-F1
%% ============================================================

function score = macroF1(yTrue,yPred,classNames)

    yTrue = string(yTrue);
    yPred = string(yPred);

    numClasses = numel(classNames);

    f1 = zeros(numClasses,1);

    for c = 1:numClasses

        cls = classNames(c);

        TP = sum((yTrue == cls) & (yPred == cls));
        FP = sum((yTrue ~= cls) & (yPred == cls));
        FN = sum((yTrue == cls) & (yPred ~= cls));

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
            f1(c) = 0;
        else
            f1(c) = ...
                2*precision*recall / ...
                (precision + recall);
        end
    end

    score = mean(f1);

end
