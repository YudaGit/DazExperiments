function merge_h1_eta_hc_warmstart()
%MERGE_H1_ETA_HC_WARMSTART Replace canonical H1-eta HC with a better refit.
%   Retains the four original participant fits, takes HC_cauchy from the
%   warm-start aggregate, backs up the canonical files, and regenerates its
%   MAT aggregate and CSV summary.

    thisDir = fileparts(mfilename('fullpath'));
    canonicalDir = fullfile(thisDir, 'TestFits', 'H1_eta');
    canonicalFile = fullfile(canonicalDir, 'H1_eta_20260914_165156.mat');
    warmFile = fullfile(thisDir, 'TestFits', 'H1_eta_HC_warmstart', ...
        'H1_eta_HC_warmstart_20260915_142317.mat');
    canonicalCsv = fullfile(canonicalDir, 'H1_eta_summary.csv');

    old = load(canonicalFile, 'allResults', 'rows', 'condLevels', ...
        'participantIDs', 'trialCounts', 'd', 'preparedDataFile', 'nStarts', ...
        'nWorkers', 'opts', 'runLabel', 'hypothesis', 'warmStartFile');
    warm = load(warmFile, 'allResults');

    fieldName = 'HC_cauchy';
    oldHC = old.allResults.(fieldName);
    newHC = warm.allResults.(fieldName);
    if newHC.bestNLL >= oldHC.bestNLL
        error('merge_h1_eta_hc_warmstart:NoImprovement', ...
            'Warm-start HC NLL %.12f does not improve canonical NLL %.12f.', ...
            newHC.bestNLL, oldHC.bestNLL);
    end

    backupSuffix = datestr(now, 'yyyymmdd_HHMMSS');
    copyfile(canonicalFile, fullfile(canonicalDir, ...
        "H1_eta_20260914_165156_preHCwarmstart_" + backupSuffix + ".mat"));
    copyfile(canonicalCsv, fullfile(canonicalDir, ...
        "H1_eta_summary_preHCwarmstart_" + backupSuffix + ".csv"));

    old.allResults.(fieldName) = newHC;
    hcRow = old.rows.uid == "HC" & old.rows.model == "cauchy";
    old.rows.NLL(hcRow) = newHC.bestNLL;
    old.rows.minus2LL(hcRow) = newHC.ll2;
    old.rows.AIC(hcRow) = newHC.qaic;
    old.rows.BIC(hcRow) = newHC.qbic;
    old.rows.bestStart(hcRow) = find(newHC.allNLL == newHC.bestNLL, 1);
    old.rows.nSuccess(hcRow) = sum(ismember(newHC.allExitflag, [1, 2]));
    old.rows.boundaryParams(hcRow) = "";
    if ~isempty(newHC.boundary)
        old.rows.boundaryParams(hcRow) = strjoin(newHC.boundary, ', ');
    end

    allResults = old.allResults;
    rows = old.rows;
    condLevels = old.condLevels;
    participantIDs = old.participantIDs;
    trialCounts = old.trialCounts;
    d = old.d;
    preparedDataFile = old.preparedDataFile;
    nStarts = old.nStarts;
    nWorkers = old.nWorkers;
    opts = old.opts;
    runLabel = old.runLabel;
    hypothesis = old.hypothesis;
    warmStartFile = old.warmStartFile;
    % This older aggregate predates the explicit layoutVersion metadata.
    % Its H1-eta vector is nevertheless the canonical 22-parameter layout.
    layoutVersion = "20260915_vnorm_kappa_eta_a_ter_st";
    save(canonicalFile, 'allResults', 'rows', 'condLevels', 'participantIDs', ...
        'trialCounts', 'd', 'preparedDataFile', 'nStarts', 'nWorkers', ...
        'opts', 'runLabel', 'hypothesis', 'warmStartFile', 'layoutVersion');
    writetable(rows, canonicalCsv);

    fprintf('Replaced canonical H1-eta HC: %.6f -> %.6f NLL.\n', ...
        oldHC.bestNLL, newHC.bestNLL);
end
