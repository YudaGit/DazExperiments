function verify_StatRvsDeterR_integrity(matPath)
% Verify design and stimulus integrity for Stat vs Deter pilot
% Usage: verify_StatRvsDeterR_integrity('StatisticalModeTest01.mat')

    if nargin < 1 || isempty(matPath)
        error('Provide a .mat path containing expTrials.');
    end

    S = load(matPath);
    expTrials = [];
    fns = fieldnames(S);
    for i = 1:numel(fns)
        if istable(S.(fns{i}))
            expTrials = S.(fns{i});
            fprintf('Using table: %s\n', fns{i});
            break;
        end
    end
    if isempty(expTrials)
        error('No table found in %s', matPath);
    end

    fprintf('\n=== Trial Balance Summary ===\n');
    conditions = unique(expTrials.Condition, 'stable');
    itemNs = unique(expTrials.ItemN);
    noiseLevels = unique(expTrials.NoiseLevel, 'stable');
    for c = 1:numel(conditions)
        for i = 1:numel(itemNs)
            for n = 1:numel(noiseLevels)
                idx = strcmp(expTrials.Condition, conditions{c}) & ...
                      expTrials.ItemN == itemNs(i) & ...
                      strcmp(expTrials.NoiseLevel, noiseLevels{n});
                fprintf('%s | N=%d | %s: %d\n', conditions{c}, itemNs(i), noiseLevels{n}, sum(idx));
            end
        end
    end
    fprintf('Total trials: %d\n', height(expTrials));

    if ismember('PresentationType', expTrials.Properties.VariableNames)
        badPres = ~strcmp(expTrials.PresentationType, 'simultaneous');
        fprintf('Non-simultaneous trials: %d\n', sum(badPres));
    end

    fprintf('\n=== Column Presence ===\n');
    for f = {'MeanOffsets','BaseHues','TileRGB','TileHues','TargetHue'}
        exists = ismember(f{1}, expTrials.Properties.VariableNames);
        fprintf('%s: %d\n', f{1}, exists);
    end

    fprintf('\n=== Stimulus Integrity ===\n');
    n = height(expTrials);
    lenOK = true;
    tilesOK = true;
    targetOK = true;
    hueOK = true;
    for i = 1:n
        N = expTrials.ItemN(i);
        if ismember('MeanOffsets', expTrials.Properties.VariableNames)
            if numel(expTrials.MeanOffsets{i}) ~= N || numel(expTrials.BaseHues{i}) ~= N
                lenOK = false;
            end
        end
        if ismember('TileRGB', expTrials.Properties.VariableNames)
            tRGB = expTrials.TileRGB{i};
            tH = expTrials.TileHues{i};
            if numel(tRGB) ~= N || numel(tH) ~= N
                tilesOK = false;
            else
                for k = 1:N
                    if size(tRGB{k},2) ~= 3
                        tilesOK = false;
                    end
                    if size(tRGB{k},1) ~= numel(tH{k})
                        tilesOK = false;
                    end
                end
            end
        end
        if expTrials.Target(i) < 1 || expTrials.Target(i) > N
            targetOK = false;
        end
        if ismember('TargetHue', expTrials.Properties.VariableNames) && isnan(expTrials.TargetHue(i))
            hueOK = false;
        end
    end

    fprintf('MeanOffsets/BaseHues length OK: %d\n', lenOK);
    fprintf('TileRGB/TileHues shape OK: %d\n', tilesOK);
    fprintf('Target index range OK: %d\n', targetOK);
    fprintf('TargetHue non-NaN OK: %d\n', hueOK);

    fprintf('\n=== TargetHue Consistency ===\n');
    diffs = nan(n,1);
    for i = 1:n
        cond = expTrials.Condition{i};
        baseH = expTrials.BaseHues{i};
        meanOff = expTrials.MeanOffsets{i};
        if strcmp(cond, 'Baseline')
            idx = expTrials.Target(i);
            calc = mod(baseH(idx) + meanOff(idx), 360);
        else
            calc = mod(baseH(1) + mean(meanOff), 360);
        end
        diffs(i) = abs(mod(calc - expTrials.TargetHue(i) + 180, 360) - 180);
    end
    fprintf('TargetHue mismatches (>1e-6): %d / %d\n', sum(diffs > 1e-6), n);
    fprintf('Max abs diff: %.9f deg\n', max(diffs));

    fprintf('\n=== Redundant MeanOffset Checks (Homo_Space) ===\n');
    sameCount = 0;
    totalHomo = 0;
    for i = 1:n
        if strcmp(expTrials.Condition{i}, 'Homo_Space')
            totalHomo = totalHomo + 1;
            offs = expTrials.MeanOffsets{i};
            if all(abs(offs - offs(1)) < 1e-9)
                sameCount = sameCount + 1;
            end
        end
    end
    fprintf('Homo_Space trials with identical mean offsets: %d / %d\n', sameCount, totalHomo);
end
