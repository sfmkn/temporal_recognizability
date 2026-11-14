function result = runCNNOuterFold(windowNumber, repeat, fold)
% Repeated cross-validation for TR-1D-CNN
% Uses original Stage 3 folds and separate inner validation.
%
% Example:
% result = runCNNOuterFold(7,1,2);

root = '/MATLAB Drive/Temporal_Recognizability_Dataset';

cvFile = fullfile(root,'Results','CrossValidation', ...
    'TR_REPEATED_CV_FOLDS_V1.mat');

CV = load(cvFile);

assert(repeat >= 1 && repeat <= CV.numRepeats);
assert(fold >= 1 && fold <= CV.numFolds);
assert(windowNumber >= 1 && windowNumber <= 20);

windowName = sprintf('W%02d',windowNumber);

outputFolder = fullfile(root,'Results','CNN_CrossValidation');

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

outputFile = fullfile(outputFolder, ...
    sprintf('CNN_%s_R%02d_F%02d.mat', ...
    windowName,repeat,fold));

% Skip completed experiments
if isfile(outputFile)
    S = load(outputFile,'result');
    result = S.result;
    fprintf('Existing result loaded: %s\n',outputFile);
    return;
end

%% 1. Original outer CV split

assignments = CV.foldAssignments(:,repeat);

outerTrainIdx = find(assignments ~= fold);
outerEvalIdx = find(assignments == fold);

outerTrainIDs = CV.devEventIDs(outerTrainIdx);
outerEvalIDs = CV.devEventIDs(outerEvalIdx);

outerTrainLabels = CV.devLabels(outerTrainIdx);
Yeval = CV.devLabels(outerEvalIdx);

assert(isempty(intersect(outerTrainIDs,outerEvalIDs)));
assert(isempty(intersect(outerEvalIDs,CV.testEventIDs)));

%% 2. Stratified inner split

% Fixed inner split for each repetition/fold
% Reused across all 20 observation windows
rng(7400 + 100*repeat + fold);

innerTrainIdx = [];
innerValIdx = [];

classNames = categories(outerTrainLabels);

for c = 1:numel(classNames)

    idx = find(outerTrainLabels == classNames{c});
    idx = idx(randperm(numel(idx)));

    nVal = round(0.20*numel(idx));

    innerValIdx = [innerValIdx; idx(1:nVal)];
    innerTrainIdx = [innerTrainIdx; idx(nVal+1:end)];

end

fitIDs = outerTrainIDs(innerTrainIdx);
valIDs = outerTrainIDs(innerValIdx);

Yfit = outerTrainLabels(innerTrainIdx);
Yval = outerTrainLabels(innerValIdx);

assert(isempty(intersect(fitIDs,valIDs)));
assert(isempty(intersect(fitIDs,outerEvalIDs)));
assert(isempty(intersect(valIDs,outerEvalIDs)));

%% 3. Load waveforms

folder = fullfile(root,'Temporal_Windows',windowName);

IDgroups = {fitIDs,valIDs,outerEvalIDs};
Xgroups = cell(3,1);

for g = 1:3

    IDs = IDgroups{g};
    X = cell(numel(IDs),1);

    for i = 1:numel(IDs)

        filename = sprintf('%s_%s.mat', ...
            char(IDs(i)),windowName);

        S = load(fullfile(folder,filename), ...
            'waveform_window');

        waveform = single(S.waveform_window);

        if size(waveform,2) == 6
            X{i} = waveform;
        elseif size(waveform,1) == 6
            X{i} = waveform';
        else
            error('Unexpected waveform dimensions.');
        end

    end

    Xgroups{g} = X;

end

Xfit = Xgroups{1};
Xval = Xgroups{2};
Xeval = Xgroups{3};

%% 4. Training-only normalization

channelSum = zeros(1,6);
channelSumSq = zeros(1,6);
totalSamples = 0;

for i = 1:numel(Xfit)

    X = double(Xfit{i});

    channelSum = channelSum + sum(X,1);
    channelSumSq = channelSumSq + sum(X.^2,1);

    totalSamples = totalSamples + size(X,1);

end

mu = channelSum/totalSamples;

variance = (channelSumSq-totalSamples*mu.^2) ...
    /(totalSamples-1);

sigma = sqrt(max(variance,0));
sigma(sigma < 1e-6) = 1;

for i = 1:numel(Xfit)
    Xfit{i} = single((double(Xfit{i})-mu)./sigma);
end

for i = 1:numel(Xval)
    Xval{i} = single((double(Xval{i})-mu)./sigma);
end

for i = 1:numel(Xeval)
    Xeval{i} = single((double(Xeval{i})-mu)./sigma);
end

%% 5. CNN architecture

architectureFile = 'TR_1D_CNN_Architecture.mat';

A = load(architectureFile,'layers');

layers = A.layers;

%% 6. CNN training

rng(751);

validationFrequency = max(1, ...
    ceil(numel(Xfit)/64));

options = trainingOptions('adam', ...
    'InitialLearnRate',0.001, ...
    'MaxEpochs',20, ...
    'MiniBatchSize',64, ...
    'Shuffle','every-epoch', ...
    'ValidationData',{Xval,Yval}, ...
    'ValidationFrequency',validationFrequency, ...
    'OutputNetwork','best-validation', ...
    'Plots','none', ...
    'Verbose',false);

fprintf('\nTraining %s, repeat %d, fold %d\n', ...
    windowName,repeat,fold);

tic;

[net,info] = trainnet( ...
    Xfit,Yfit,layers,'crossentropy',options);

trainingSeconds = toc;

%% 7. Outer-fold evaluation

scores = minibatchpredict(net,Xeval);

pred = scores2label(scores,categories(Yeval));

accuracy = mean(pred == Yeval);

C = confusionmat(Yeval,pred, ...
    'Order',categorical(categories(Yeval)));

TP = diag(C);

precision = TP./max(sum(C,1)',1);
recall = TP./max(sum(C,2),1);

f1 = 2.*precision.*recall./max(precision+recall,eps);

macroF1 = mean(f1);

%% 8. Save experiment

result = struct();

result.window = windowNumber;
result.repeat = repeat;
result.fold = fold;

result.fitCount = numel(Yfit);
result.validationCount = numel(Yval);
result.evaluationCount = numel(Yeval);

result.accuracy = accuracy;
result.macroF1 = macroF1;

result.confusionMatrix = C;
result.perClassF1 = f1;

result.trainingSeconds = trainingSeconds;
result.selectedIteration = info.OutputNetworkIteration;

result.fitIDs = fitIDs;
result.validationIDs = valIDs;
result.evaluationIDs = outerEvalIDs;

save(outputFile,'result','net','info','mu','sigma', ...
    'options','-v7.3');

fprintf('Accuracy: %.2f%%\n',100*accuracy);
fprintf('Macro-F1: %.2f%%\n',100*macroF1);
fprintf('Training time: %.2f seconds\n',trainingSeconds);

fprintf('Saved: %s\n',outputFile);

end