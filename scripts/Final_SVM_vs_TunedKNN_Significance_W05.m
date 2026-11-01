%% ============================================================
% FINAL FAIR STATISTICAL COMPARISON
% RBF-SVM vs TUNED KNN at W05 = T/8
%
% Uses the 25 matched repeated-CV evaluations:
%   5 folds x 5 repeats
%
% NO TEST-SET DATA ARE USED.
% ============================================================

clear;
clc;

fprintf('\n====================================================\n');
fprintf(' FINAL FAIR SVM vs TUNED-KNN TEST — W05 (T/8)\n');
fprintf('====================================================\n\n');

rootDir = '/MATLAB Drive/Temporal_Recognizability_Dataset';

cvDir = fullfile(rootDir,'Results','CrossValidation');


%% ============================================================
% 1. LOAD EXISTING SVM REPEATED-CV RESULTS
% ============================================================

svmFile = fullfile( ...
    cvDir, ...
    'Temporal_RepeatedCV_Final.mat');

assert(isfile(svmFile), ...
    'Existing SVM CV results not found.');

S = load(svmFile);

fprintf('SVM result file loaded.\n');
fprintf('Variables in SVM file:\n');
disp(fieldnames(S));


%% ============================================================
% 2. LOAD NEW FAIR-TUNED KNN RESULTS
% ============================================================

knnFile = fullfile( ...
    cvDir, ...
    'TunedKNN_RepeatedCV_29Budget_V1.mat');

assert(isfile(knnFile), ...
    'Tuned KNN CV results not found.');

K = load(knnFile);

fprintf('\nTuned-KNN result file loaded.\n');
fprintf('Variables in tuned-KNN file:\n');
disp(fieldnames(K));


%% ============================================================
% 3. EXTRACT W05 = T/8
% ============================================================

windowIndex = 5;

% New tuned KNN
knnAcc = K.accuracyAll(windowIndex,:)';

assert(numel(knnAcc) == 25, ...
    'Expected 25 tuned-KNN evaluations.');


%% ============================================================
% 4. LOCATE SVM ACCURACY MATRIX SAFELY
%
% We do NOT guess if the expected variable is unavailable.
% ============================================================

if isfield(S,'svmAccuracyAll')

    svmAcc = S.svmAccuracyAll(windowIndex,:)';

elseif isfield(S,'SVM_accuracy_all')

    svmAcc = S.SVM_accuracy_all(windowIndex,:)';

elseif isfield(S,'svmAccAll')

    svmAcc = S.svmAccAll(windowIndex,:)';

elseif isfield(S,'accuracySVM')

    svmAcc = S.accuracySVM(windowIndex,:)';

else

    fprintf('\nSTOPPING SAFELY.\n');
    fprintf('Could not identify the SVM 20x25 accuracy matrix.\n');
    fprintf('Do NOT calculate statistics manually yet.\n');
    fprintf('Send me the variable listing printed above.\n');

    return;
end


assert(numel(svmAcc) == 25, ...
    'Expected 25 SVM evaluations.');

fprintf('\n25 matched SVM evaluations recovered.\n');
fprintf('25 matched tuned-KNN evaluations recovered.\n');


%% ============================================================
% 5. PAIRED DIFFERENCES
% ============================================================

d = svmAcc - knnAcc;

meanSVM = mean(svmAcc);
sdSVM   = std(svmAcc,0);

meanKNN = mean(knnAcc);
sdKNN   = std(knnAcc,0);

meanDiff = mean(d);
sdDiff   = std(d,0);

n = numel(d);

fprintf('\n====================================================\n');
fprintf(' DESCRIPTIVE RESULTS\n');
fprintf('====================================================\n');

fprintf('SVM       = %.2f%% +/- %.2f%%\n', ...
    100*meanSVM,100*sdSVM);

fprintf('Tuned KNN = %.2f%% +/- %.2f%%\n', ...
    100*meanKNN,100*sdKNN);

fprintf('Difference = %.2f percentage points\n', ...
    100*meanDiff);


%% ============================================================
% 6. PAIRED t-TEST
% ============================================================

[h_t,p_t,ci_t,stats_t] = ttest(svmAcc,knnAcc);

fprintf('\n====================================================\n');
fprintf(' PAIRED t-TEST\n');
fprintf('====================================================\n');

fprintf('t(%d) = %.4f\n', ...
    stats_t.df,stats_t.tstat);

fprintf('p = %.6g\n',p_t);

fprintf('95%% CI for paired difference = [%.2f, %.2f] pp\n', ...
    100*ci_t(1),100*ci_t(2));


%% ============================================================
% 7. WILCOXON SIGNED-RANK TEST
% ============================================================

[p_w,h_w,stats_w] = signrank(svmAcc,knnAcc);

fprintf('\n====================================================\n');
fprintf(' WILCOXON SIGNED-RANK TEST\n');
fprintf('====================================================\n');

fprintf('p = %.6g\n',p_w);

if isfield(stats_w,'signedrank')
    fprintf('Signed rank = %.4f\n',stats_w.signedrank);
end

if isfield(stats_w,'zval')
    fprintf('z = %.4f\n',stats_w.zval);
end


%% ============================================================
% 8. PAIRED EFFECT SIZE — COHEN dz
% ============================================================

cohenDz = meanDiff / sdDiff;

fprintf('\n====================================================\n');
fprintf(' PAIRED EFFECT SIZE\n');
fprintf('====================================================\n');

fprintf('Cohen dz = %.4f\n',cohenDz);


%% ============================================================
% 9. NORMALITY CHECK OF PAIRED DIFFERENCES
% ============================================================

[h_lillie,p_lillie] = lillietest(d);

fprintf('\n====================================================\n');
fprintf(' NORMALITY CHECK — PAIRED DIFFERENCES\n');
fprintf('====================================================\n');

fprintf('Lilliefors p = %.6g\n',p_lillie);

if h_lillie == 0
    fprintf('Normality not rejected at alpha = 0.05.\n');
else
    fprintf('Normality rejected at alpha = 0.05.\n');
end


%% ============================================================
% 10. RANGE AND DIRECTION OF PAIRED DIFFERENCES
% ============================================================

fprintf('\n====================================================\n');
fprintf(' PAIRED DIFFERENCE CHECK\n');
fprintf('====================================================\n');

fprintf('Minimum difference = %.2f pp\n',100*min(d));
fprintf('Maximum difference = %.2f pp\n',100*max(d));

fprintf('SVM higher in %d of %d matched evaluations.\n', ...
    sum(d > 0),n);


%% ============================================================
% 11. SAVE FINAL FAIR STATISTICAL RESULT
% ============================================================

resultFile = fullfile( ...
    cvDir, ...
    'FINAL_SVM_vs_TunedKNN_W05_Significance_V1.mat');


save(resultFile, ...
    'svmAcc','knnAcc','d', ...
    'meanSVM','sdSVM', ...
    'meanKNN','sdKNN', ...
    'meanDiff','sdDiff', ...
    'p_t','ci_t','stats_t', ...
    'p_w','stats_w', ...
    'cohenDz', ...
    'p_lillie');


fprintf('\nResults saved:\n%s\n',resultFile);


fprintf('\n====================================================\n');
fprintf(' FINAL FAIR SIGNIFICANCE ANALYSIS COMPLETE\n');
fprintf('====================================================\n');

fprintf('\nLocked test set was NOT used.\n');