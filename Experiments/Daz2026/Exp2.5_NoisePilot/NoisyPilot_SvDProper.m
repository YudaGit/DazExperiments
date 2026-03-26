%======================================================================
% NoisyPilot_SvDProper.m   (Set-size 1 + Statistical vs Deterministic)
% Pilot: Set sizes 1, 2, 6; set-size 1 = single condition per noise;
%        N=2,6 have Baseline + Homo redundancy; sampling mode alternates by session.
% Stimulus ring: ArrayRotationDeg = random per trial; StimulusLocations are stored as
%   already-rotated on-screen azimuths in the trial table. WheelRotation = session wheel.
% Data: saves under ./Data/ next to this file (see getExperimentDataDir); copy the whole
%   experiment folder to another machine — no path edits needed.
%======================================================================

clear; close all; clc;
sca; Screen('CloseAll');
format shortg;
InitializeMatlabOpenGL; AssertOpenGL;
KbName('UnifyKeyNames');

% Participant info
timestamp     = datestr(now,'yyyy-mm-dd_HH-MM-SS');
participantID = input('Enter Participant ID: ','s');
sessionN      = str2double(input('Enter Session Number (1–10): ','s'));
age           = str2double(input('Enter Age (17–99): ','s'));
gender        = str2double(input('Enter Gender (0=M,1=W,2=O): ','s'));
if isempty(participantID) || isnan(sessionN)||isnan(age)||isnan(gender) || ...
   sessionN<1||sessionN>10 || age<17||age>99 || ~ismember(gender,0:2)
    error('Invalid participant details.');
end

% Design specification for SvD Proper: Set-size 1 + Stat vs Deter by session
design.ItemNList    = [1 2 6];         % Set sizes: N=1, N=2, N=6
design.NoiseLevels  = {'low', 'high'}; % Noise levels
design.SetSize1Reps = 25;              % Trials per noise for N=1 (single condition; baseline = homo)
design.BaselineReps = 25;              % Per N×Noise for N=2,6 (Baseline)
design.HomoReps     = 25;              % Per N×Noise for N=2,6 (Homo_Space)
design.PracticeReps = 5;               % Practice trials per session (before main block)
% Timing: values here are copied into V.Durations after initiate() (see below).
% Trial loop uses only V.Durations — not per-trial table columns.
design.presDur      = 0.40;            % → V.Durations.PresentationDuration (stimulus on-screen, s)
design.retDur       = 1.0;             % → V.Durations.RetentionDuration (masked retention before response, s)
design.SegmentDur   = 0.30;            % Unused for timing; kept for compatibility
design.ISI          = 0.20;            % → V.Durations.InterSegmentInterval (between segments, s)

% Debug mode: print and exit without PTB window (set DebugNoPTB false for real pilot)
DebugVerify = false;
DebugNoPTB = false;
DebugVerifyTrials = 3;
DebugSkipInstructions = false;

if DebugVerify && DebugNoPTB
    global V
    global P
    global StimStats
    V.color.rotation = randi([0, 359]);
    V.square.B = 10;
    V.color.map = buildColorMapNoPTB();
    P.K_LowNoise  = 10;
    P.K_HighNoise = 0.78;
    P.samplingMode = 'deterministic';
    if size(V.color.map,1) == 360
        P.cMap360_255 = V.color.map;
    else
        idx = round(linspace(1, size(V.color.map,1), 360));
        P.cMap360_255 = V.color.map(idx, :);
    end
    P.PrecomputeStimuli = false;
    P.DebugDrawNoiseLevel = false;
    P.DebugVerify = DebugVerify;
    P.DebugVerifyTrials = DebugVerifyTrials;
    P.DebugSkipInstructions = DebugSkipInstructions;
    [pracTrials, expTrials] = TrialMatrixSeq3way_SvDProper(design, sessionN, participantID, age, timestamp);
    printTrialBalance(expTrials);
    expTrials = precomputeStimuli(expTrials, P);
    printStimulusChecks(expTrials, DebugVerifyTrials);
    return;
end

% Global & PTB window
global V
global P  % Noise parameters for noisy stimuli
global StimStats
V = initiate();             % your existing helper: opens window & sets V
win = V.window;
V.PrintScreens = false;     % don't save screenshots by default

% Central timing for this experiment (lab convention: V.Durations.*)
V.Durations.PresentationDuration   = design.presDur;
V.Durations.RetentionDuration      = design.retDur;
V.Durations.InterSegmentInterval   = design.ISI;

% Generate practice & main tables
[pracTrials, expTrials] = TrialMatrixSeq3way_SvDProper(design, sessionN, participantID, age, timestamp);

% Print trial balance summary
printTrialBalance(expTrials);

% Calibration & textures
VA5deg        = calibrateMonitor();
adjustSquareStim(VA5deg);  % Use square stimulus adjustment for noisy squares
wheelTex      = DrawWheel();
neutralTex    = DrawNeutralWheel(); %#ok<NASGU> % reserved if orientation-cue trials added

% Noise parameters (EXACTLY matching NoiseDemo_VMRand.m)
P.K_LowNoise      = 10;       % concentration parameter (high = narrow distribution)
                                % Higher kappa = tighter clustering around target
                                % Typical range: 20-100 for low noise
P.K_HighNoise     = 0.78;         % concentration parameter (lower = wider distribution)
                                % Lower kappa = wider spread around target
                                % Typical range: 1-10 for high noise
% Note: For better discriminability, aim for kappa ratio > 10:1
%       (e.g., Low=50, High=2 gives 25:1 ratio)
% Alternate sampling mode by session: odd = deterministic, even = statistical
if mod(sessionN, 2) == 1
    P.samplingMode = 'deterministic';
else
    P.samplingMode = 'statistical';
end
fprintf('Session %d: sampling mode = %s\n', sessionN, P.samplingMode);
P.DebugVerify    = DebugVerify;          % true: run limited trials and print checks
P.DebugVerifyTrials = DebugVerifyTrials; % number of trials to run before stopping
P.DebugSkipInstructions = DebugSkipInstructions;    % skip instructions in debug verify
P.PrecomputeStimuli = true;       % precompute tile patterns and target hue (false = on-the-fly)
P.AssertUniqueRedundant = true;   % error if redundant items are identical (rounded)
P.LogRedundantFingerprint = false;% if true, print mean/std/sum(round(h)) per item for debugging
P.SaveStimulusSnap = false;       % save each trial's stimulus display as PNG for inspection
P.DebugDrawNoiseLevel = false;   % true: fprintf noise level every segment (very verbose)
P.nPracticeTrials = design.PracticeReps;  % for instructions text
% Prepare color map for noisy stimuli (360-row lookup)
if size(V.color.map,1) == 360
    P.cMap360_255 = V.color.map;
else
    idx = round(linspace(1, size(V.color.map,1), 360));
    P.cMap360_255 = V.color.map(idx, :);
end

% Precompute stimuli patterns + offsets if enabled
if isfield(P, 'PrecomputeStimuli') && P.PrecomputeStimuli
    expTrials = precomputeStimuli(expTrials, P);
    if height(pracTrials) > 0
        pracTrials = precomputeStimuli(pracTrials, P);
    end
end

% Per-trial stimulus snap folders (when P.SaveStimulusSnap is true)
snapDirMain = [];
snapDirPrac = [];
if isfield(P, 'SaveStimulusSnap') && P.SaveStimulusSnap
    saveDirBase = getExperimentDataDir();
    baseSnap = fullfile(saveDirBase, 'StimulusSnaps', sprintf('%s_sess%d_%s', participantID, sessionN, timestamp));
    snapDirMain = fullfile(baseSnap, 'Main');
    if ~isfolder(snapDirMain)
        mkdir(snapDirMain);
    end
    fprintf('Main stimulus snaps: %s\n', snapDirMain);
    if height(pracTrials) > 0
        snapDirPrac = fullfile(baseSnap, 'Practice');
        if ~isfolder(snapDirPrac)
            mkdir(snapDirPrac);
        end
        fprintf('Practice stimulus snaps: %s\n', snapDirPrac);
    end
end

try
    skipInst = isfield(P, 'DebugVerify') && P.DebugVerify && P.DebugSkipInstructions;
    runPractice = height(pracTrials) > 0 && ~skipInst;

    if runPractice
        instructions(2);
        pracTrials = runSvDProperTrialBlock(pracTrials, win, wheelTex, snapDirPrac, false);
    end

    if ~skipInst
        instructions(3);
    end

    doDbg = isfield(P, 'DebugVerify') && P.DebugVerify;
    [expTrials, mainStoppedEarly] = runSvDProperTrialBlock(expTrials, win, wheelTex, snapDirMain, doDbg);
    if mainStoppedEarly
        printStimulusChecks(expTrials, P.DebugVerifyTrials);
        ExperimentEnd(true);
        return;
    end

    SaveData(expTrials, sessionN, participantID, timestamp, P, design);
    ExperimentEnd(true);

catch ME
    disp('An error occurred:'); disp(ME.message);
    try
        disp(getReport(ME, 'extended'));
    catch %#ok<CTCH>
    end
    ExperimentEnd(false);
end


% Display Functions
%========================================================
function [T, stoppedEarly] = runSvDProperTrialBlock(T, win, wheelTex, snapDir, doDebugEarlyExit)
% Run one block (practice or main). stoppedEarly true if debug early-exit after DebugVerifyTrials.
% Stimulus/retention/ISI timing: V.Durations.PresentationDuration, RetentionDuration, InterSegmentInterval.
    global V
    global P
    global StimStats
    stoppedEarly = false;
    nTot = height(T);
    for ii = 1:nTot
        tr = T(ii,:);
        Screen('FillRect', win, V.patch.bg);
        fixation(0);
        Screen('Flip', win);
        WaitSecs(V.Durations.FixationDuration);
        shownLocations = [];
        StimStats.meanOffsets = nan(1, tr.ItemN);
        StimStats.baseHues = nan(1, tr.ItemN);
        StimStats.condition = tr.Condition{1};
        StimStats.tileHues = cell(1, tr.ItemN);
        StimStats.trialIndex = ii;
        allSegs = tr.SegmentOrder{1};
        locs = effectiveStimulusAzimuthsDeg(tr);
        for seg = 1:numel(allSegs)
            idxList = allSegs{seg};
            Screen('FillRect', win, V.patch.bg);
            fixation(0);
            if ~isempty(shownLocations)
                DrawMasksAtLocations(shownLocations);
            end
            DrawStimulusSegment(tr, idxList);
            Screen('Flip', win);
            % Full presentation duration with stimulus on-screen; snap AFTER wait so GetImage/imwrite
            % does not inflate presentation time.
            WaitSecs(V.Durations.PresentationDuration);
            if ~isempty(snapDir)
                saveTrialStimulusSnap(win, ii, seg, snapDir);
            end
            for k = idxList
                angleDeg = locs(k);
                if ~ismember(angleDeg, shownLocations)
                    shownLocations = [shownLocations, angleDeg];
                end
            end
            Screen('FillRect', win, V.patch.bg);
            fixation(0);
            DrawMasksAtLocations(shownLocations);
            Screen('Flip', win);
            if seg < numel(allSegs)
                WaitSecs(V.Durations.InterSegmentInterval);
            end
        end
        targetHue = computeTargetHue(tr, StimStats);
        T.TargetHue(ii) = targetHue;
        T.MeanOffsets{ii} = StimStats.meanOffsets;
        T.BaseHues{ii} = StimStats.baseHues;
        Screen('FillRect', win, V.patch.bg);
        fixation(0);
        DrawMasksAtLocations(shownLocations);
        Screen('Flip', win);
        WaitSecs(V.Durations.RetentionDuration);
        [ T.MouseX{ii}, T.MouseY{ii}, T.MouseAngles{ii}, T.MouseDistances{ii}, ...
          T.MouseTime{ii}, T.ResponseTime(ii), T.ResponseAngle(ii), ...
          T.DerotatedResponseAngle(ii), T.Precision(ii) ] = ...
            GetResponse(T(ii,:), wheelTex);
        [ T.MouseInitTooSlow(ii), T.MouseInitTooFast(ii), T.TrialTooSlow(ii) ] = speedCheck(T(ii,:));
        DrawWheelFeedback(T(ii,:), wheelTex);
        penalty  = T.TrialTooSlow(ii)*V.Durations.FeedbackPenaltyDuration;
        standard = ~T.TrialTooSlow(ii)*V.Durations.FeedbackDuration;
        WaitSecs(penalty+standard);
        DrawIntertrialFeedbackFast(T(1:ii,:), win, V.windowRect, nTot);
        if doDebugEarlyExit && isfield(P, 'DebugVerifyTrials') && P.DebugVerifyTrials > 0 && ii >= P.DebugVerifyTrials
            stoppedEarly = true;
            break;
        end
    end
end

function dataDir = getExperimentDataDir()
% Local data folder: <folder containing NoisyPilot_SvDProper.m>/Data
% Works when the experiment folder is copied to another machine (no absolute paths).
    persistent cachedDir
    if isempty(cachedDir)
        thisFile = mfilename('fullpath');
        if isempty(thisFile)
            expDir = pwd;
        else
            expDir = fileparts(thisFile);
        end
        dataDir = fullfile(expDir, 'Data');
        if ~isfolder(dataDir)
            mkdir(dataDir);
        end
        cachedDir = dataDir;
    else
        dataDir = cachedDir;
    end
end

function rot = getArrayRotationDeg(trial)
% Per-trial rotation of the stimulus ring (deg), independent of V.color.rotation (wheel).
    rot = 0;
    if istable(trial) && ismember('ArrayRotationDeg', trial.Properties.VariableNames)
        r = trial.ArrayRotationDeg(1);
        if isfinite(r) && ~isnan(r)
            rot = double(r);
        end
    elseif isstruct(trial) && isfield(trial, 'ArrayRotationDeg') && ~isempty(trial.ArrayRotationDeg)
        r = trial.ArrayRotationDeg;
        if isfinite(r) && ~isnan(r)
            rot = double(r);
        end
    end
    rot = mod(rot, 360);
end

function locs = effectiveStimulusAzimuthsDeg(trial)
% Screen azimuths (deg) used for drawing on this trial.
% Trial matrix now stores StimulusLocations as already-rotated per-trial azimuths.
    canon = trial.StimulusLocations{1};
    if iscell(canon)
        canon = canon{1};
    end
    locs = mod(double(canon(:))', 360);
end

function drawRings(tr)
    % Draw 6 fixed square location indicators (always 6, regardless of set size)
    % Squares are 1.1x larger than the stimulus squares
    global V
    numLocations = 6;  % Always show 6 location indicators
    baseAngle = 90;    % Template at 12 o'clock; add per-trial array rotation
    rot = getArrayRotationDeg(tr);
    
    % Calculate square indicator size (1.1x larger than stimulus)
    indicatorSize = V.square.side_px_full * 1.1;
    halfSize = indicatorSize / 2;
    
    % Evenly spaced around circle (same rotation as stimulus array)
    for j = 1:numLocations
        angleDeg = mod(baseAngle + (j-1) * (360/numLocations) + rot, 360);
        theta = deg2rad(angleDeg);
        x = V.centerX + V.stim.positionradius * cos(theta);
        y = V.centerY - V.stim.positionradius * sin(theta);
        
        % Draw square frame (1px white border)
        sqRect = [-halfSize, -halfSize, halfSize, halfSize];
        squareRect = CenterRectOnPointd(sqRect, x, y);
        Screen('FrameRect', V.window, [255 255 255], squareRect, 1);
    end
end

function DrawStimulusSegment(trial, idx)
    global V
    global P  % Noise parameters for noisy stimuli
    global StimStats
    % allow {idx} or idx
    if iscell(idx), idx = idx{1}; end
    idx = idx(:)';                      % row

    locs = effectiveStimulusAzimuthsDeg(trial);
    cols = trial.Colors{1};
    
    % Get noise level from trial (if available), default to 'low'
    % IMPORTANT: NoiseLevel is a trial-level property - all stimuli in a trial
    % use the same noise level. This ensures consistency within each trial.
    if istable(trial) && ismember('NoiseLevel', trial.Properties.VariableNames)
        % Access from table row - handle both cell array and string array
        noiseVal = trial.NoiseLevel;
        if iscell(noiseVal)
            noiseLevel = noiseVal{1};
        elseif isstring(noiseVal) || ischar(noiseVal)
            noiseLevel = char(noiseVal);
        else
            noiseLevel = char(noiseVal(1));
        end
        % Ensure it's a char array for comparison
        if isstring(noiseLevel)
            noiseLevel = char(noiseLevel);
        end
    elseif isfield(trial, 'NoiseLevel') && ~isempty(trial.NoiseLevel)
        noiseLevel = trial.NoiseLevel{1};
    else
        noiseLevel = 'low';  % Default to low noise
    end
    
    if isfield(P, 'DebugDrawNoiseLevel') && P.DebugDrawNoiseLevel
        fprintf('DrawStimulusSegment: NoiseLevel = "%s"\n', noiseLevel);
    end

    % All stimuli in this segment use the same noise level (trial-level property)
    for k = idx
        targetHueDeg = cols(k);
        angleDeg = locs(k);
        
        % Generate noisy pattern (mode-dependent)
        usedPrecompute = false;
        % Do NOT use ~isempty(TileRGB{1}): enrich stores scalar nan there, which is
        % non-empty — then trial.TileRGB{1}{k} errors. Require real precomputed cell.
        nIt = trial.ItemN;
        if iscell(nIt), nIt = nIt(1); end
        tc = []; th = [];
        if istable(trial) && ismember('TileRGB', trial.Properties.VariableNames)
            tc = trial.TileRGB{1};
        end
        if istable(trial) && ismember('TileHues', trial.Properties.VariableNames)
            th = trial.TileHues{1};
        end
        preOk = isfield(P, 'PrecomputeStimuli') && P.PrecomputeStimuli && ...
                istable(trial) && ismember('TileRGB', trial.Properties.VariableNames) && ...
                iscell(tc) && iscell(th) && numel(tc) >= nIt && numel(th) >= nIt && ...
                isnumeric(tc{1}) && ~isempty(tc{1}) && isnumeric(th{1}) && ~isempty(th{1});
        if preOk
            rgb01 = tc{k};
            huesDeg = th{k};
            StimStats.meanOffsets(k) = trial.MeanOffsets{1}(k);
            StimStats.baseHues(k) = trial.BaseHues{1}(k);
            usedPrecompute = true;
        else
            [rgb01, huesDeg] = getPatternByMode(V, targetHueDeg, noiseLevel, P, k);
            if strcmpi(StimStats.condition, 'Homo_Space') && ...
               isfield(P, 'samplingMode') && strcmpi(P.samplingMode, 'statistical')
                maxResample = 10;
                resampleCount = 0;
                while any(cellfun(@(h) isequal(round(h), round(huesDeg)), StimStats.tileHues(1:k-1)))
                    [rgb01, huesDeg] = getPatternByMode(V, targetHueDeg, noiseLevel, P, k);
                    resampleCount = resampleCount + 1;
                    if resampleCount >= maxResample
                        break;
                    end
                end
            end
            meanOffset = calculateMeanOffset(huesDeg, targetHueDeg);
            StimStats.meanOffsets(k) = meanOffset;
            StimStats.baseHues(k) = targetHueDeg;
        end
        StimStats.tileHues{k} = huesDeg;
        
        % Draw noisy square at location
        drawNoisySquareAt(V, targetHueDeg, noiseLevel, angleDeg, P, rgb01);
    end

    if strcmpi(StimStats.condition, 'Homo_Space') && ...
       isfield(P, 'samplingMode') && strcmpi(P.samplingMode, 'statistical')
        checkRedundantUniqueness(StimStats.tileHues, P, StimStats.trialIndex, usedPrecompute);
    end
end

% Instruction
function [] = instructions(n)
% Display of multiple instructions (n), Next = Mouse Click (L)
% Can set position and text size
    global V
    global P
    m = .25;
    if n == 1
        inst = ['Welcome to the colour-report task.\n\n\n' ...
                    'In each trial, the screen will show six color circles.\n' ...
                    'Please try to remember all colors.\n' ...
                    'Report the color of the cued target \n' ...
                    'using the mouse and the response color wheel'];
    elseif n == 2
        np = 5;
        if isfield(P, 'nPracticeTrials') && ~isempty(P.nPracticeTrials)
            np = P.nPracticeTrials;
        end
        inst = sprintf(['Practice block (%d trials)\n\n\n' ...
            'These trials match the main task (set sizes, noise, redundancy).\n' ...
            'Practice responses are saved separately and are not part of the main dataset.\n\n' ...
            'When you are ready, begin the practice block.'], np); 
    elseif n == 3
        % Include sampling mode for this session (deterministic vs statistical)
        modeStr = 'deterministic';
        if isfield(P, 'samplingMode') && strcmpi(P.samplingMode, 'statistical')
            modeStr = 'statistical';
        end
        inst = ['Main block:\n\n' ...
            'These are the main experimental trials. \n\n' ...
            'Sampling mode this session: ' modeStr '.\n\n' ...
            'There will be a between-trial feedback plot. \n' ...
            'It visualises your performance and overall progress \n' ...
            'You can rest and refocus during these feedback displays.\n\n\n'];
    elseif n == 4
        inst = ['444'];
    elseif n == 5
        inst =['555'];
    end
    Screen('TextSize', V.window, 50);
    DrawFormattedText(V.window, inst, 'center', V.windowRect(4) * m, [255, 255, 255]);
    DrawFormattedText(V.window, 'Press The Left Mouse Button To Continue', 'center', V.windowRect(4) * .95, [255, 255, 255]);
    Screen('Flip', V.window);
    WaitForMouseClick(); 
end

% Inter-trial feedback
function DrawIntertrialFeedbackFast(trialsSoFar, winPtr, winRect, nTotal)
    % Precision-per-trial bar plot with PTB drawing only, plus persisted fixation.
    % trialsSoFar: table for Precision (deg error)
    % winPtr, winRect = Psychtoolbox window pointer & rect

    if nargin < 4
        error('DrawIntertrialFeedbackFast: must supply total trial count as fourth argument');
    end
    nDone = height(trialsSoFar);
    if nDone == 0, return; end

    barW      = 1; % bar width px
    spaceW    = 1; % bar spacing px
    plotH     = 220;
    bottomY   = winRect(4) * 0.92;
    barColor  = [129 199 212];  % RGB color for all bars
    white     = [255 255 255];  % text & axis color

    % HORIZONTAL MARGINS FOR CENTERING
    totalW = nTotal * (barW + spaceW);
    leftMargin = round((winRect(3) - totalW) / 2);

    % DRAW BACKGROUND
    Screen('FillRect', winPtr, [128 128 128]);

    % DRAW FIXATION USING EXISTING FUNCTION
    fixation(0);

    % DRAW BARS
    for i = 1:nDone
        err   = abs(trialsSoFar.Precision(i));
        score = 1 - min(err / 180, 1);    % normalized 0..1
        hPx   = round(score * plotH);
        xLeft = leftMargin + (i) * (barW + spaceW);
        rect  = [xLeft, bottomY - hPx, xLeft + barW, bottomY];
        Screen('FillRect', winPtr, barColor, rect);
    end

    % DRAW AXES
    axisX0 = leftMargin;
    axisX1 = leftMargin + totalW;
    axisY0 = bottomY;
    axisY1 = bottomY - plotH;
    Screen('DrawLine', winPtr, white, axisX0, axisY0, axisX1, axisY0, 2);
    Screen('DrawLine', winPtr, white, axisX0, axisY0, axisX0, axisY1, 2);

    % DRAW Y-TICKS & LABELS
    Screen('TextSize', winPtr, 14);
    yTicks = 0:2:10;
    for yt = yTicks
        yPx = bottomY - (yt / 10) * plotH;
        Screen('DrawLine', winPtr, white, axisX0 - 5, yPx, axisX0, yPx, 1);
        label = sprintf('%d', yt);
        Screen('DrawText', winPtr, label, axisX0 - 30, yPx - 7, white);
    end

    % AXIS TITLES
    Screen('TextSize', winPtr, 18);
    Screen('DrawText', winPtr, 'Precision Score', axisX0 - 20, axisY1 - 30, white);
    Screen('DrawText', winPtr, 'Trial', axisX0 + totalW/2 - 10, axisY0 + 20, white);

    % DRAW FINISH LINE
    xFinish = leftMargin + (nTotal) * (barW + spaceW) + barW/2;
    Screen('DrawLine', winPtr, white, xFinish, axisY0, xFinish, axisY1, 2);

    % DISPLAY MESSAGES
    infoTxt1 = sprintf('Completed Trial %d of %d', nDone, nTotal);
    Screen('TextSize', winPtr, 24);
    DrawFormattedText(winPtr, infoTxt1, 'center', winRect(4) * 0.37, white);
    DrawFormattedText(winPtr, 'Click to continue', 'center', winRect(4) * 0.4, white);

    % FINAL FLIP
    Screen('Flip', winPtr);
    WaitForMouseClick();
end

function drawLineMarker(centerX, centerY, angle, color)
    global V
    % Calculate the start and end points of the line based on the angle
    xStart = centerX - (V.feedback.ticklength / 2) * cos(angle);
    yStart = centerY - (V.feedback.ticklength / 2) * sin(angle);
    xEnd = centerX + (V.feedback.ticklength / 2) * cos(angle);
    yEnd = centerY + (V.feedback.ticklength / 2) * sin(angle);
    Screen('DrawLine', V.window, color, xStart, yStart, xEnd, yEnd, V.feedback.linewidth);
end

function [] = DrawWheelFeedback(trial, wheelTexture, orientationTexture)
    global V
    if trial.CuedFeature_i == 0 %color
        Screen('DrawTexture', V.window, wheelTexture, [], [], V.color.rotation);
        rspAngle = deg2rad(mod(trial.ResponseAngle + V.color.rotation, 360));
        % Feedback target should match scoring target (trial.TargetHue), not raw base hue.
        if isfield(trial, 'TargetHue') && ~isnan(trial.TargetHue)
            trueTargetHue = trial.TargetHue;
        else
            % Fallback for compatibility if TargetHue is missing.
            trueTargetHue = trial.Colors{1}(trial.Target);
        end
        targetAngle = deg2rad(mod(trueTargetHue + V.color.rotation, 360));

        rspX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(rspAngle);
        rspY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(rspAngle);
        tarX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(targetAngle);
        tarY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(targetAngle);
        drawLineMarker(rspX, rspY, rspAngle, [255, 0, 0]);  % Red for response angle
        drawLineMarker(tarX, tarY, targetAngle, [0, 255, 0]);  % Green for target angle
    
    else % orientation
        Screen('DrawTexture', V.window, orientationTexture);
        rspAngle = deg2rad(mod(trial.ResponseAngle - 90, 360));
        targetAngle = deg2rad(mod(trial.Orientations{1}(trial.Target) - 90, 360));

        rspX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(rspAngle);
        rspY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(rspAngle);
        tarX =  V.centerX + V.annulus.radiusOuter * 1.1 * cos(targetAngle);
        tarY =  V.centerY + V.annulus.radiusOuter * 1.1 * sin(targetAngle);
        drawLineMarker(rspX, rspY, rspAngle, [255, 0, 0]);  % Red for response angle
        drawLineMarker(tarX, tarY, targetAngle, [0, 255, 0]);  % Green for target angle
    end
    drawShortestArc(rspAngle, targetAngle);
    fixation(0);
    if trial.TrialTooSlow
        feedback = 'Response Too Slow'; 
    elseif trial.MouseInitTooSlow
        feedback = 'Initial Mouse Movement Too Slow'; 
    elseif trial.MouseInitTooFast
        feedback = 'Initial Mouse Movement Too Fast'; 
    end
    if trial.TrialTooSlow || trial.MouseInitTooSlow || trial.MouseInitTooFast
        Screen('TextSize', V.window, 40);
        DrawFormattedText(V.window, feedback, 'center', V.windowRect(4)/2, [255, 0, 0]);
    end
    Screen('Flip', V.window);
end

function drawShortestArc(startAngle, endAngle)
    global V
    arcRadius = V.annulus.radiusOuter * 1.1;
    numSegments = 90;
    clockwiseDistance = mod(endAngle - startAngle, 2 * pi);
    counterClockwiseDistance = mod(startAngle - endAngle, 2 * pi);
    if clockwiseDistance <= counterClockwiseDistance
        arcExtent = clockwiseDistance;
        direction = 1;  % Clockwise
    else
        arcExtent = counterClockwiseDistance;
        direction = -1;  % Counterclockwise
    end
    angleIncrement = arcExtent / numSegments;
    for ii = 1:numSegments
        currentAngle = startAngle + direction * (ii - 1) * angleIncrement;
        nextAngle = startAngle + direction * ii * angleIncrement;

        % Calculate the positions of the current and next points on the arc
        x1 = V.centerX + arcRadius * cos(currentAngle);
        y1 = V.centerY + arcRadius * sin(currentAngle);
        x2 = V.centerX + arcRadius * cos(nextAngle);
        y2 = V.centerY + arcRadius * sin(nextAngle);

        % Draw a line between the current point and the next point
        Screen('DrawLine', V.window, [0, 255, 0], x1, y1, x2, y2, V.feedback.linewidth);
    end
end

function v = StimulusDurations(v)
% ALL timing parameters in V.Durations.*
% If you call it with V only, it keeps whatever is already there.
% If you pass new vectors, they overwrite the lists.

% single-value legacy fields (kept for old helpers that expect them)
v.Durations.FixationDuration       = 1.000;
%V.Durations.PreCueDuration         = 0.30;
% SvD Proper main loop (runSvDProperTrialBlock): overwritten from design.* after initiate()
v.Durations.PresentationDuration   = 0.40;  % stimulus on-screen per segment (s)
v.Durations.RetentionDuration      = 1.00;   % masked retention before response (s)
v.Durations.InterSegmentInterval   = 0.20;  % ISI between segments with masks on (s)
v.Durations.StimulusDuration       = [0.10 0.15 0.20 0.25 0.30 0.35]; % legacy: condition-wise list (other scripts)
v.Durations.MaskDuration           = 0.750;
v.Durations.FeedbackDuration       = 0.750;
v.Durations.FeedbackPenaltyDuration= 2.00;
v.Durations.ResponseDuration       = 10.0;
v.Durations.TrialTooSlow           = 3000;  % ms
v.Durations.RetinalColorReset      = 0.005;
end

function TargetCue(trial, refresh)
    global V
    if ~exist('refresh', 'var')
        refresh = true;
    end
    
    % Draw all masks first
    DrawAllMasks(trial);
    
    % Then draw white outline around the cued target mask
    locsEff = effectiveStimulusAzimuthsDeg(trial);
    targetAngle = locsEff(trial.Target);
    theta = deg2rad(targetAngle);
    centerX = round(V.centerX + V.stim.positionradius * cos(theta));
    centerY = round(V.centerY - V.stim.positionradius * sin(theta));  % Note: -sin for y-axis (screen coordinates)
    
    % Draw white outline square (1.1x larger than stimulus, matching location indicator style)
    squareSize = V.square.side_px_full;
    indicatorSize = squareSize * 1.1;
    halfSize = indicatorSize / 2;
    sqRect = [-halfSize, -halfSize, halfSize, halfSize];
    cueRect = CenterRectOnPointd(sqRect, centerX, centerY);
    Screen('FrameRect', V.window, [255 255 255], cueRect, 1);
    
    fixation(0);
    if refresh
        Screen('Flip', V.window);
    end
end


function noiseMaskTex = GaussianTextureSquare()
    % Create static B×B grid mask matching stimulus structure
    % Equal numbers of dark gray and light gray tiles in a fixed checkerboard-like pattern
    % Texture is cached and reused (never closed)
    global V
    persistent cachedMaskTex cachedB cachedSize
    
    B = V.square.B;
    squareSize = V.square.side_px_full;
    
    % Check if we can reuse cached texture (same B and size)
    if ~isempty(cachedMaskTex) && cachedB == B && cachedSize == squareSize
        % Verify texture is still valid
        try
            Screen('WindowKind', cachedMaskTex);
            noiseMaskTex = cachedMaskTex;
            return;
        catch
            % Texture was closed, need to recreate
            cachedMaskTex = [];
        end
    end
    
    tilePx = V.square.tile_px;
    nTiles = B * B;
    
    % Create mask image
    maskImage = zeros(squareSize, squareSize, 3, 'uint8');
    
    % Define dark and light gray values
    darkGray = round(255 * 0.3);   % Dark gray (~30% intensity)
    lightGray = round(255 * 0.7);  % Light gray (~70% intensity)
    
    % Create static checkerboard-like pattern: alternate dark/light
    % This ensures equal numbers (or as close as possible) in a fixed pattern
    for r = 0:B-1
        for c = 0:B-1
            rowStart = round(r * tilePx) + 1;
            rowEnd = round((r + 1) * tilePx);
            colStart = round(c * tilePx) + 1;
            colEnd = round((c + 1) * tilePx);
            
            % Ensure indices are within bounds
            rowStart = max(1, rowStart);
            rowEnd = min(squareSize, rowEnd);
            colStart = max(1, colStart);
            colEnd = min(squareSize, colEnd);
            
            % Static pattern: checkerboard (alternate based on row+col)
            if mod(r + c, 2) == 0
                grayVal = darkGray;
            else
                grayVal = lightGray;
            end
            
            maskImage(rowStart:rowEnd, colStart:colEnd, 1) = grayVal;  % R
            maskImage(rowStart:rowEnd, colStart:colEnd, 2) = grayVal;  % G
            maskImage(rowStart:rowEnd, colStart:colEnd, 3) = grayVal;  % B
        end
    end
    
    noiseMaskTex = Screen('MakeTexture', V.window, maskImage);
    
    % Cache the texture for reuse (DO NOT CLOSE THIS TEXTURE)
    cachedMaskTex = noiseMaskTex;
    cachedB = B;
    cachedSize = squareSize;
end

function noiseMaskTex = GaussianTexture()
    global V
    patchSize = round(V.stim.pedestalradius * 2);
    meanGray  = round(255/2);
    noiseAmp  = round(255/4);
    sigma     = round(patchSize * .25);
    noise2D = (rand(patchSize) * 2 - 1)*noiseAmp + meanGray;
    noise2D = max(0, min(noise2D, 255));
    [x, y] = meshgrid( ...
        linspace(-patchSize/2, +patchSize/2, patchSize), ...
        linspace(-patchSize/2, +patchSize/2, patchSize) );
    distFromCenter = sqrt(x.^2 + y.^2);
    circleMask = (distFromCenter <= V.stim.pedestalradius);
    gauss2D    = exp( -(distFromCenter.^2) / (2*sigma^2) );
    alpha2D = gauss2D .* circleMask;
    noiseImage = zeros(patchSize, patchSize, 4, 'uint8');
    noiseImage(:,:,1) = uint8(noise2D);                 % R
    noiseImage(:,:,2) = uint8(noise2D);                 % G
    noiseImage(:,:,3) = uint8(noise2D);                 % B
    noiseImage(:,:,4) = uint8(alpha2D * 255);           % alpha
    noiseMaskTex = Screen('MakeTexture', V.window, noiseImage);
end

function DrawMaskAtLocation(angleDeg)
    % Draw a square mask at a specific location (used after each stimulus)
    % Uses cached static mask texture (never closed)
    global V
    theta = deg2rad(angleDeg);
    centerX = round(V.centerX + V.stim.positionradius * cos(theta));
    centerY = round(V.centerY - V.stim.positionradius * sin(theta));  % Note: -sin for y-axis (screen coordinates)
    squareSize = V.square.side_px_full;
    maskRect = CenterRectOnPointd([0, 0, squareSize, squareSize], centerX, centerY);
    
    noiseMaskTex = GaussianTextureSquare();  % Returns cached texture (never closed)
    Screen('DrawTexture', V.window, noiseMaskTex, [], maskRect);
    % DO NOT close the texture - it's cached and reused
end

function DrawMasksAtLocations(locs)
    % Draw masks at specified locations (list of angles in degrees)
    global V
    for j = 1:numel(locs)
        DrawMaskAtLocation(locs(j));
    end
end

function DrawAllMasks(trial)
    % Draw masks at all stimulus locations (used during retention and response)
    global V
    locs = effectiveStimulusAzimuthsDeg(trial);
    DrawMasksAtLocations(locs);
end

function Mask(trial)
    % Legacy function - kept for compatibility
    global V
    locsEff = effectiveStimulusAzimuthsDeg(trial);
    for ii = 1:trial.ItemN
        noiseMaskTex = GaussianTexture;
        theta = deg2rad(locsEff(ii));
        centerX = V.centerX + V.stim.positionradius * cos(theta);
        centerY = V.centerY - V.stim.positionradius * sin(theta);
        basePedestal = [0, 0, V.stim.pedestalradius * 2, V.stim.pedestalradius * 2];
        centeredPedestal = CenterRectOnPointd(basePedestal, centerX, centerY);
        Screen('FillOval', V.window, V.cue.Bgcolor, centeredPedestal);
        Screen('DrawTexture', V.window, noiseMaskTex, [], centeredPedestal);
        Screen('Close', noiseMaskTex);
    end
    fixation(0);
    Screen('Flip', V.window);
end

function [] = fixation(duration)
    global V
    fixCrossDimPix = 10;
    xCoords = [-fixCrossDimPix, fixCrossDimPix, 0, 0];
    yCoords = [0, 0, -fixCrossDimPix, fixCrossDimPix];
    allCoords = [xCoords; yCoords];
    lineWidthPix = 2;
    Screen('DrawLines', V.window, allCoords, lineWidthPix, repmat(255*.25,1,3), [V.centerX, V.centerY]);
    circleRadius = fixCrossDimPix; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, V.centerX, V.centerY);
    Screen('FrameOval', V.window, repmat(255*.25,1,3), circleRect, lineWidthPix);
    circleRadius = 2; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, V.centerX, V.centerY);
    Screen('FrameOval', V.window, repmat(255*.75,1,3), circleRect, lineWidthPix);
    rect = [V.centerX - V.mouseinit.radius, V.centerY - V.mouseinit.radius, ...
            V.centerX + V.mouseinit.radius, V.centerY + V.mouseinit.radius];
    Screen('FrameOval', V.window, V.mouseinit.color, rect, V.mouseinit.radiusWidth);
    if duration > 0
        Screen('Flip', V.window);
        WaitSecs(duration);
    end
end

function texture = DrawNeutralWheel()
    global V
    
    offScreenWindow = Screen('OpenOffscreenWindow', ...
                 V.window, V.patch.bg, V.windowRect);
    width = V.feedback.linewidth * 2;
    blending = [128,128,128,255*.25];
    diam  = 2*V.annulus.radiusOuter;
    diamI = 2*V.annulus.radiusInner + width;
    radIn  = V.annulus.radiusInner;
    radOut = V.annulus.radiusOuter;
    
    noise  = uint8((rand(diam,diam) - 0.5) * 255 + 127.5);
    [x, y] = meshgrid(-radOut+0.5 : radOut-0.5, -radOut+0.5 : radOut-0.5);
    r      = hypot(x, y);
    alpha  = uint8(255 * (r >= radIn & r <= radOut)); 
    
    imgRGBA         = uint8(zeros(diam, diam, 4));
    imgRGBA(:,:,1)  = noise;           % R
    imgRGBA(:,:,2)  = noise;           % G
    imgRGBA(:,:,3)  = noise;           % B
    imgRGBA(:,:,4)  = alpha;           % α
    
    Screen('BlendFunction', offScreenWindow, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    noiseTex = Screen('MakeTexture', V.window, imgRGBA, [], 1); % keep 8-bit α
    dstRect  = CenterRectOnPointd([0 0 diam diam], ...
                                 V.centerX, V.centerY);
    dstRectI = CenterRectOnPointd([0 0 diamI diamI], ...
                                 V.centerX, V.centerY);
    Screen('DrawTexture', offScreenWindow, noiseTex, [], dstRect);
    
    Screen('FrameOval', offScreenWindow, blending, dstRect, width);
    Screen('FrameOval', offScreenWindow, blending, dstRectI, width);
    
    rect = [V.centerX - V.mouseinit.radius, ...
            V.centerY - V.mouseinit.radius, ...
            V.centerX + V.mouseinit.radius, ...
            V.centerY + V.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, V.mouseinit.color, ...
           rect, V.mouseinit.radiusWidth);
    
    texture = Screen('MakeTexture', V.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
    Screen('Close', noiseTex);
end

function texture = DrawWheel()
    global V
    offScreenWindow = Screen('OpenOffscreenWindow', V.window, V.patch.bg, V.windowRect);
    % Draw the color wheel onto the screen
    for ii = 1:length(V.color.angles)
        % Calculate the endpoint of each line in the annulus
        xStart = V.centerX + V.annulus.radiusInner * cos(V.color.angles(ii));
        yStart = V.centerY + V.annulus.radiusInner * sin(V.color.angles(ii));
        xEnd = V.centerX + V.annulus.radiusOuter * cos(V.color.angles(ii));
        yEnd = V.centerY + V.annulus.radiusOuter * sin(V.color.angles(ii));
        Screen('DrawLine', offScreenWindow, V.color.map(ii, :), xStart, yStart, xEnd, yEnd, 2);
    end
    
    rect = [V.centerX - V.mouseinit.radius, V.centerY - V.mouseinit.radius, ...
            V.centerX + V.mouseinit.radius, V.centerY + V.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, V.mouseinit.color, rect, V.mouseinit.radiusWidth);
    
    % Save the current screen content as a texture
    texture = Screen('MakeTexture', V.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
end

function CueCreation(display)
    global V
    theta = deg2rad(1);
    centerX = V.centerX + V.stim.positionradius * cos(theta);
    centerY = V.centerY - V.stim.positionradius * sin(theta);
    basePedestal = [0, 0, V.stim.pedestalradius * 2, V.stim.pedestalradius * 2];
    centeredPedestal = CenterRectOnPointd(basePedestal, centerX, centerY);

    if display
        for cues = 1:3

            if cues == 2
                % Add gentle wave
                %Screen('FrameOval', Visual.window, Visual.cue.Oricolor, centeredPedestal, Visual.cue.borderwidth);
                waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    V.cue.Ravg, ...
                    V.cue.gentleAmp, ...
                    V.cue.gentleFreq);
                Screen('FillPoly', V.window, [255 255 255], waveCoords)

            elseif cues == 3
                % Add spiky wave
                %Screen('FrameOval', Visual.window, Visual.cue.Colcolor, centeredPedestal, Visual.cue.borderwidth);
                waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    V.cue.Ravg, ...
                    V.cue.spikyAmp, ...
                    V.cue.spikyFreq);
                Screen('FillPoly', V.window, [255 255 255], waveCoords)
            elseif cues == 1
                % Add smooth boarder, of equal area to waves.
                %Screen('FrameOval', Visual.window, Visual.cue.Neutcolor, centeredPedestal, Visual.cue.borderwidth);
                cueSurface = [0, 0, V.cue.radius * 2, V.cue.radius * 2];
                centeredCue = CenterRectOnPointd(cueSurface, centerX, centerY);
                Screen('FillOval', V.window, [255 255 255], centeredCue);
            end

            % Add black pedestal overlay
            Screen('FillOval', V.window, V.cue.Bgcolor, centeredPedestal);

            fixation(0);
            Screen('Flip', V.window);
            WaitSecs(1);
        end
    end
end

% Response Functions
% ========================================================

function [] = WaitForMouseClick()
    global V
    valid = false;

    % Flush mouse and keyboard events
    FlushMouseEvents();  % Flush any existing mouse clicks
    FlushEvents('keyDown');  % Flush any existing keydown events

    while ~valid
        [~, ~, buttons] = GetMouse;
        [keyIsDown, ~, keyCode] = KbCheck;
        
        if buttons(1)  % Check for left mouse click
            valid = true; 
        end
        
        if keyIsDown && keyCode(V.Keys.ctrlKey) && keyCode(V.Keys.quitKey)
            disp('Quit Buttons Pressed. Erroring Out Of The Experiment...');
            QuitButtonsPressed;
        end
        
        WaitSecs(0.008);  % check each frame, 0.008 for 120hz, 0.016 for 60hz
    end
end

function FlushMouseEvents()
    % Continuously check the mouse status and only exit when no buttons are pressed
    while any(GetMouseButtons())
        % Wait briefly to avoid overloading the CPU
        WaitSecs(0.01);
    end
end

function buttons = GetMouseButtons()
    % Helper function to return the mouse button status
    [~, ~, buttons] = GetMouse;
end

function [relativeX, relativeY, angle, distance] = TrackMouse()
    global V
    % Get the current mouse position
    [mouseX, mouseY] = GetMouse(V.window);
    
    % Calculate the relative position from the center of the screen
    relativeX = mouseX - V.centerX;
    relativeY = mouseY - V.centerY;
    
    % Calculate the angle (in degrees) relative to the center
    angle = atan2d(relativeY, relativeX);
    if angle < 0
        angle = angle + 360; % Ensure the angle is between 0 and 359.99 degrees
    end
    
    % Calculate the distance from the center
    distance = sqrt(relativeX^2 + relativeY^2);
end

function [x, y, angles, distances, mousetime, rt, responseangle, derotatedAngle, precision]= GetResponse(trial, wheelTexture, orientationTexture)
    global V
    Screen('FillRect', V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    if trial.CuedFeature_i == false
        Screen('DrawTexture', V.window, wheelTexture, [], [], V.color.rotation);
    else
        Screen('DrawTexture', V.window, orientationTexture);
    end
    fixation(0);
    %Cue(trial, true, false, false)
    TargetCue(trial, false);
    Screen('Flip', V.window);
    looptime = GetSecs;
    starttime = looptime;
    checkmousetime = 10; %ms 
    Run = true;
    initiate = true;
    x = [];
    y = [];
    angles = [];
    distances = [];
    mousetime = [];
    SetMouse(V.centerX, V.centerY, V.window);
    ShowCursor('Arrow');
    FlushEvents('keyDown'); 
    while Run
        checktime = GetSecs;
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(V.Keys.ctrlKey) && keyCode(V.Keys.quitKey)
            disp('Quit Buttons Pressed. Erroring Out Of The Experiment...');
            QuitButtonsPressed;
        end
        if ((checktime - looptime) * 1000) > checkmousetime | initiate
            initiate = false;
            looptime = GetSecs();
            mousetime = [mousetime, (GetSecs() - starttime) * 1000];
            [relativeX, relativeY, angle, distance] = TrackMouse();
            x = [x, relativeX];
            y = [y, relativeY];
            angles = [angles, angle];
            distances = [distances, distance];
        end

        if distance > V.annulus.radiusInner 
            
            Run = false;
            rt = mousetime(end);

            if trial.CuedFeature_i == true
                responseangle = mod(angles(end) + 90, 360);
                derotatedAngle = angles(end);
                precision = trial.Orientations{1}(trial.Target) - responseangle;
                if precision < -180; precision = precision + 360; end
                if precision > 180; precision = precision - 360; end

            else
                responseangle = mod(angles(end) - V.color.rotation, 360);
                derotatedAngle = mod( responseangle - trial.WheelRotation, 360 );
            if isfield(trial, 'TargetHue') && ~isnan(trial.TargetHue)
                targetHue = trial.TargetHue;
            else
                targetHue = trial.Colors{1}(trial.Target);
            end
            precision = targetHue - responseangle;
                if precision < -180; precision = precision + 360; end
                if precision > 180; precision = precision - 360; end
            end
            %fprintf('Finish Angle: %f', responseangle);
            
        end

        if (GetSecs() - starttime) > V.Durations.ResponseDuration
            rt = V.Durations.ResponseDuration * 1000;
            responseangle = nan;
            derotatedAngle = nan;
            precision = nan;
            Run = false;
        end 
    end
    HideCursor();
end

function [MouseTooSlow, MouseTooFast, TrialTooSlow] = speedCheck(trial)
    global V
    MouseTooSlow = false; 
    MouseTooFast = false; 
    TrialTooSlow = false;
    LeaveCenterRT = trial.MouseTime{1}(find(trial.MouseDistances{1} >= V.mouseinit.radius, 1));

    if LeaveCenterRT > V.mouseinit.tooslow
        MouseTooSlow = true;
    end
    if LeaveCenterRT < V.mouseinit.toofast
        MouseTooFast = true;
    end
    if trial.ResponseTime > V.Durations.TrialTooSlow
        TrialTooSlow = true;
    end
end

function v = ResponseKeys()
    v.ctrlKey = KbName('LeftControl');  
    v.quitKey = KbName('l');
end

% Design and Data Functions
% =======================================================

function d = minCircularDistance(angle, angles)
    diff = abs(angle - angles);
    d = min(diff, 360 - diff);
end

function x = randColors(n)
    minDist = 15;
    maxloop = 20;
    loopcount = 0;
    x = randi([1, 360]);
    if n > 1
        while length(x) < n
            if loopcount == maxloop
                x = randi([1, 360]);
            end
            xi = randi([1, 360]);
            if all(minCircularDistance(x, xi) > minDist)
                x = [x,xi];
            else 
                loopcount = loopcount + 1;
            end
        end
    end
end

function [] = SaveData(expTrials, sessionN, participantID, timestamp, P, design)
% Main session save: expTrials table + V + P (sampling params) + design (reps) + ids.
    global V
    if nargin < 6 || isempty(design)
        design = struct();
    end
    if nargin < 5 || isempty(P)
        P = struct();
    end
    saveDir = getExperimentDataDir();
    if ~isfolder(saveDir)
        mkdir(saveDir);
        disp(['Save Data Directory Created: ', saveDir]);
    end
    fname = sprintf('SvDProper_%s_sess%d_%s.mat', ...
                    participantID, sessionN, timestamp);
    fullpath = fullfile(saveDir, fname);
    try
        save(fullpath, 'expTrials', 'V', 'P', 'design', 'sessionN', 'participantID', 'timestamp', '-v7.3');
        fprintf('Data saved to:\n  %s\n', fullpath);
    catch ME
        warning('Failed to save data: %s\nError message:\n%s', ...
                fullpath, ME.message);
    end
    disp(['Data file: ', fname, ' in ', saveDir]);
end


% Global Functions
% ========================================================
function v = initiate() %Global variable with hard-coded defaults.

sca;                   
Screen('CloseAll');    
WaitSecs(0.5);

v.patch.bg = .5 * 255; % Background gray
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0); % Minimal feedback

% Use the monitor with the highest screen index (typically the external monitor)
% This ensures the experiment runs on the external monitor
screens = Screen('Screens');
screenToUse = max(screens);  % External monitor (highest index)

% Get screen information for debugging
for s = screens
    screenRect = Screen('Rect', s);
    fprintf('Screen %d: rect = [%d, %d, %d, %d], size = %d x %d\n', ...
        s, screenRect(1), screenRect(2), screenRect(3), screenRect(4), ...
        screenRect(3)-screenRect(1), screenRect(4)-screenRect(2));
end

[v.window, v.windowRect] = Screen('OpenWindow', screenToUse, [v.patch.bg, v.patch.bg, v.patch.bg]);
Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); % can use alpha values
Screen('Flip', v.window);

% Calculate center - windowRect coordinates are relative to the screen the window is on
% For drawing operations, we need coordinates relative to the window itself
% When windowRect has non-zero offsets (multi-monitor setups), we need to account for this
windowWidth = v.windowRect(3) - v.windowRect(1);
windowHeight = v.windowRect(4) - v.windowRect(2);
v.centerX = windowWidth / 2;
v.centerY = windowHeight / 2;

% Debug output to verify center calculation
fprintf('\n=== Window Information ===\n');
fprintf('Available screens: %s\n', mat2str(screens));
fprintf('Using screen: %d\n', screenToUse);
fprintf('Window rect (screen coords): [%d, %d, %d, %d]\n', v.windowRect(1), v.windowRect(2), v.windowRect(3), v.windowRect(4));
fprintf('Window size: %d x %d pixels\n', windowWidth, windowHeight);
fprintf('Calculated center (window-relative): X=%.1f, Y=%.1f\n', v.centerX, v.centerY);
fprintf('==========================\n\n');

 % Warm-up background flip
    Screen('FillRect', v.window, [v.patch.bg, v.patch.bg, v.patch.bg]);
    Screen('Flip', v.window);
    WaitSecs(0.1);

    % Warm-up font engine (PTB loads fonts lazily)
    Screen('TextSize', v.window, 36);
    DrawFormattedText(v.window, '.', 'center', 'center', [255 255 255]);
    Screen('Flip', v.window);
    WaitSecs(0.1);

    % Optional: preload inter-trial texture (if available now)
    % This avoids lag at first display
    % You can skip this here if texture generation is not yet possible
    % feedbackTex = GenerateFeedbackTexture(...);
    % Screen('DrawTexture', V.window, feedbackTex);
    % Screen('Flip', V.window);
    % WaitSecs(0.1);

    % Flush input buffers
    FlushEvents('keyDown');
    FlushMouseEvents();

useCIE_LABcolorwheel = false; % if false, use OK_LAB Color wheel.

if useCIE_LABcolorwheel
    % This LAB color wheel was selected by Yi and Paul 16/04/2025
    %    using the LABolorspaceSelection.m code which accompanies
    %    this experiment code. Selection was based for the perception
    %    of relatively comparable color-zones around the wheel, however,
    %    this was a subjective assessment at the time based on a specific
    %    testing monitor. Color perceptions are subject to change.
    v.color.L = 65;
    v.color.a = 20;
    v.color.b = 0;
    v.color.radius = 70;
    v.color.incriments = 360 * 5;

    v.color.angles = 0:2*pi/v.color.incriments:2*pi;
    v.color.map(:,2:3) = v.color.radius*[cos(v.color.angles') sin(v.color.angles')];
    v.color.map(:,1) = v.color.L;
    v.color.map(:,2) = v.color.map(:,2) + v.color.a;
    v.color.map(:,3) = v.color.map(:,3) + v.color.b;
    v.color.map(end,:) = [];
    v.color.angles = v.color.angles(1:end-1);
    v.color.labmap = v.color.map;

    cform = makecform('lab2srgb');
    v.color.map = applycform(v.color.map, cform) * 255;
else

    % This is the OKlab color space selected by Paul on the 06/05/2025
    % following Hang (Allen) Qian's suggested usage. This is a perceptually
    % smoother color wheel based in LAB space, which should suit our
    % purposes.
    v.color.L          = 0.85;            % lightness (0–1, 1 = D65 white)
    v.color.radius     = 0.23;            % chroma radius
    v.color.increments = 360 * 7;         % spokes

    v.color.angles = 0 : 2*pi/v.color.increments : 2*pi;
    v.color.map    = zeros(numel(v.color.angles), 3);      % pre-allocate
    
    % a- and b- coordinates around the circle
    v.color.map(:,2:3) = v.color.radius * [cos(v.color.angles')  sin(v.color.angles')];
    v.color.map(:,1)   = v.color.L;                      % column 1 = L
    v.color.map(end,:) = [];                             % remove duplicate 0/2π sample
    v.color.angles     = v.color.angles(1:end-1);
    rgbLin             = okLab2linSRGB(v.color.map);     % linear sRGB (0–1)
    rgb                = lin2srgb(rgbLin);               % γ-encoded sRGB
    rgb                = max(min(rgb,1),0);              % hard-clip gamut
    v.color.map        = rgb * 255;                      % match your LAB wheel

end

v.color.rotation = randi([0, 359]);
v = StimulusDurations(v);
v.Keys = ResponseKeys();
end

function linRGB = okLab2linSRGB(okLab)
% okLab2linSRGB  Convert OKLab to linear sRGB (0–1)
%
% Reference: Björn Ottosson’s OKLab specification, Nov-2020
%
L = okLab(:,1);   a = okLab(:,2);   b = okLab(:,3);

l_ = L + 0.3963377774*a + 0.2158037573*b;
m_ = L - 0.1055613458*a - 0.0638541728*b;
s_ = L - 0.0894841775*a - 1.2914855480*b;

LMS = [l_.^3, m_.^3, s_.^3]; % undo cube root

M = [ 4.0767416621, -3.3077115913,  0.2309699292;
     -1.2684380046,  2.6097574011, -0.3413193965;
     -0.0041960863, -0.7034186147,  1.7076147010];
linRGB = LMS * M.';
end

function srgb = lin2srgb(linRGB)
% lin2srgb  Linear sRGB (0–1) → γ-encoded sRGB (0–1)
th = 0.0031308;
srgb            = zeros(size(linRGB));
mask            = linRGB <= th;
srgb(mask)      = 12.92 * linRGB(mask);
srgb(~mask)     = 1.055 * linRGB(~mask).^(1/2.4) - 0.055;
end

function fiveDegVA_in_pixels = calibrateMonitor()
    global V
    % Physical width of 5° at this distance (must match participant setup during the task).
    CALIB_VIEWING_DISTANCE_MM = 600;

    % check calibration exists
    currentConfig.pcName = getenv('COMPUTERNAME');
    currentConfig.monitorPositions = get(0, 'MonitorPositions');
    calibFilename = 'screenCalibration.mat';

    if exist(calibFilename, 'file')
        loadedData = load(calibFilename, 'savedConfig', 'calibrationData');
        if ~isequal(loadedData.savedConfig, currentConfig)
            runCalibration = true;
        else
            runCalibration = false;
            fiveDegVA_in_pixels = loadedData.calibrationData;
        end
    else
        runCalibration = true;
    end

    if runCalibration

        DrawFormattedText(V.window, ...
            ['Align these two lines with the edges of your credit card.\n\n' ...
            'Sit at the same viewing distance as during the experiment (~60 cm).\n\n' ...
            'Use LEFT/RIGHT arrow keys to move each line.\n' ...
            'Use UP/DOWN arrow keys to choose which line moves.\n' ...
            'Press ENTER when done.'], ...
            'center', 'center', [255 255 255]);
        Screen('Flip', V.window);
        WaitSecs(1);
        blank(0);
    
        leftLineX = V.centerX - V.centerX * .33;
        rightLineX = V.centerX + V.centerX * .33;
        currentLine = 'left';
    
        done = false;
        moveStep = 1; % 1 pixel for precision
        while ~done
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown
                if keyIsDown && keyCode(V.Keys.ctrlKey) && keyCode(V.Keys.quitKey)
                    disp('Quit Buttons Pressed. Erroring Out Of The Experiment...');
                    QuitButtonsPressed;
                end
                if keyCode(KbName('LeftArrow'))
                    if strcmp(currentLine, 'left')
                        leftLineX = leftLineX - moveStep;
                    else
                        rightLineX = rightLineX - moveStep;
                    end
                elseif keyCode(KbName('RightArrow'))
                    if strcmp(currentLine, 'left')
                        leftLineX = leftLineX + moveStep;
                    else
                        rightLineX = rightLineX + moveStep;
                    end
                elseif keyCode(KbName('UpArrow')) || keyCode(KbName('DownArrow'))
                    if strcmp(currentLine, 'left')
                        currentLine = 'right';
                    else
                        currentLine = 'left';
                    end
                    WaitSecs(0.1);
                elseif any( [keyCode(KbName('Return')), keyCode(KbName('return')+1)] )
                    done = true;
                end
                blank(0);
            end
            
            if strcmp(currentLine, 'left')
                lineIndicatorLeft = [255 255 255];   % maybe the same color, or highlight
                lineIndicatorRight = [0 0 0];  % dim color for non-selected
            else
                lineIndicatorLeft = [0 0 0];
                lineIndicatorRight = [255 255 255];
            end
    
            Screen('DrawLine', V.window, lineIndicatorLeft, ...
                leftLineX, 0, leftLineX, V.windowRect(4), 2);
            Screen('DrawLine', V.window, lineIndicatorRight, ...
                rightLineX, 0, rightLineX, V.windowRect(4), 2);
            DrawFormattedText(V.window, ...
                'Use arrow keys to move lines. Press ENTER when done.', ...
                'center', 50, [255 255 255]);
            Screen('Flip', V.window);
            WaitSecs(0.01);
    
        end
        blank(0);
        measured = rightLineX - leftLineX;
        CreditCardWith = 85.60;
        pixelsPerMm = measured / CreditCardWith;
        % Must match participant viewing distance during the experiment (see adjustSquareStim header).
        viewingdistance = CALIB_VIEWING_DISTANCE_MM;
        desiredAngleDeg = 5; % reference span used to compute px/deg (width of 5° in pixels)
        stim_in_mm = 2 * viewingdistance * tan((desiredAngleDeg / 2) * (pi/180));
        fiveDegVA_in_pixels = round( stim_in_mm * pixelsPerMm );

        savedConfig = currentConfig; 
        calibrationData = fiveDegVA_in_pixels; 
        save('screenCalibration.mat', 'savedConfig', 'calibrationData');
    end

end

function [] = adjustSquareStim(VA5deg)
% ADJUSTSQUARESTIM  Visual-angle geometry for upright noisy square stimuli.
%
% INPUT
%   VA5deg — Pixel width on screen that subtends 5° at the calibrated viewing
%            distance (from calibrateMonitor: credit-card width + 600 mm distance).
%            pxPerDeg = VA5deg / 5.
%
% VIEWING DISTANCE
%   Must match calibrateMonitor (600 mm = 60 cm). If the participant sits
%   closer/farther, px/deg from calibration will be wrong — re-run calibration
%   or change CALIB_VIEWING_DISTANCE_MM in both calibrateMonitor and here.
%
% LAYOUT (degrees at that distance)
%   Stimulus square side length ≈ STIM_SIDE_DEG (default 1°).
%   Stimulus centers lie on a circle of radius STIM_RING_RADIUS_DEG (default 4.75°,
%   within 4.5–5°). The response wheel annulus is placed outside the stimulus ring.

    global V

    % Must match calibrateMonitor CALIB_VIEWING_DISTANCE_MM.
    CALIB_VIEWING_DISTANCE_MM = 600;

    % ---- Stimulus layout (degrees) — edit these if you change the design ----
    STIM_SIDE_DEG          = 1.0;    % side length of each square (~1° VA)
    STIM_RING_RADIUS_DEG   = 1.88;   % radius from fixation to stimulus centers (4.5–5°)

    % ---- Validate inputs ----
    if ~isfield(V,'window') || isempty(V.window) || ~Screen('WindowKind', V.window)
        error('adjustSquareStim:InvalidWindow','V.window is not a valid PTB window.');
    end
    if ~isscalar(VA5deg) || ~isfinite(VA5deg) || VA5deg<=0
        error('adjustSquareStim:InvalidVA5','VA5deg must be a positive finite scalar (pixels).');
    end

    V.pxPerDeg = VA5deg / 5;

    % Radial extent: ring radius + half diagonal of square (corner farthest from fixation)
    half_diag_deg = STIM_SIDE_DEG * sqrt(2) / 2;
    % Response wheel outside stimulus array (avoid overlap with squares)
    WHEEL_ANNULUS_INNER_DEG = STIM_RING_RADIUS_DEG + half_diag_deg + 0.25;
    WHEEL_ANNULUS_OUTER_DEG = WHEEL_ANNULUS_INNER_DEG + 0.55;

    V.layout.calibViewingDistanceMm   = CALIB_VIEWING_DISTANCE_MM;
    V.layout.stimSquareSideDeg        = STIM_SIDE_DEG;
    V.layout.stimulusRingRadiusDeg    = STIM_RING_RADIUS_DEG;
    V.layout.maxStimulusExtentDeg     = STIM_RING_RADIUS_DEG + half_diag_deg;
    V.layout.wheelAnnulusInnerDeg     = WHEEL_ANNULUS_INNER_DEG;
    V.layout.wheelAnnulusOuterDeg     = WHEEL_ANNULUS_OUTER_DEG;
    V.layout.stimRingRadiusPx         = max(1, round(V.pxPerDeg * STIM_RING_RADIUS_DEG));

    degpx = V.pxPerDeg;
    V.feedback.linewidth   = max(1, round(degpx * .08));
    V.feedback.ticklength  = round(degpx * .50);

    V.annulus.radiusInner  = round(degpx * WHEEL_ANNULUS_INNER_DEG);
    V.annulus.radiusOuter  = round(degpx * WHEEL_ANNULUS_OUTER_DEG);

    V.stim.positionradius  = round(degpx * STIM_RING_RADIUS_DEG);

    % Square: corners on inscribed circle; side length = sqrt(2)*R_deg = STIM_SIDE_DEG
    V.square.coverage_c    = 1.00;
    V.square.R_deg         = STIM_SIDE_DEG / sqrt(2);
    V.square.B             = 10;

    side_deg_full          = V.square.coverage_c * sqrt(2) * V.square.R_deg;
    side_px_full           = max(V.square.B, round(side_deg_full * V.pxPerDeg));
    side_px_full           = side_px_full - mod(side_px_full, V.square.B);
    V.square.side_px_full  = max(V.square.B, side_px_full);
    V.square.tile_px       = V.square.side_px_full / V.square.B;

    V.stim.pedestalradius = round(degpx * .56 * 1.3);
    V.stim.pedestalcolor = [0, 0, 0];
    V.stim.radius = round(degpx * .56);

    V.mouseinit.radius = round(degpx * .4);
    V.mouseinit.radiusWidth = round(degpx * .03);
    V.mouseinit.color = [85, 85, 85];
    V.mouseinit.toofast = 200;
    V.mouseinit.tooslow = 50000;

    V.cue.Bgcolor = [0, 0, 0];
    V.cue.PedestalMultiplier = 1.1;
    V.cue.radius = V.stim.pedestalradius * V.cue.PedestalMultiplier;
    V.cue.ringArea = pi * (V.cue.radius^2 - V.stim.pedestalradius^2);
    V.cue.gentleFreq = 8;
    V.cue.spikyFreq  = 36;
    V.cue.Ravg = (V.stim.pedestalradius + V.cue.radius)/2;

    fprintf(['Geometry: %.2f° square side, %.2f° stimulus-ring radius (centers), ' ...
        'max radial extent ~%.2f°; response wheel %.2f–%.2f° (viewing distance %d mm).\n'], ...
        STIM_SIDE_DEG, STIM_RING_RADIUS_DEG, V.layout.maxStimulusExtentDeg, ...
        WHEEL_ANNULUS_INNER_DEG, WHEEL_ANNULUS_OUTER_DEG, CALIB_VIEWING_DISTANCE_MM);
end

function [] = blank(duration)
    global V
    Screen('FillRect', V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    Screen('Flip', V.window);
    if duration > 0
        WaitSecs(duration);
    end
end

function x = randOrientations(n)
    minDist = 30;
    maxloop = 20;
    loopcount = 0;
    x = randi([0, 179]);
    if n > 1
        while length(x) < n
            if loopcount == maxloop
                x = randi([0, 179]);
            end
            xi = randi([0, 179]);
            if all(minCircularDistance(x, xi) > minDist)
                x = [x,xi];
            else 
                loopcount = loopcount + 1;
            end
        end
    end
end

function [] = QuitButtonsPressed()
% Clean exit handler when Ctrl+L is pressed
    global V
    try
        sca;
        Screen('CloseAll');
    catch
    end
    disp('Experiment terminated by user.');
    error('Experiment terminated by user (Ctrl+L).');
end

function [] = ExperimentEnd(Finished)
    global V
    try
        % Check if window is still valid before trying to use it
        windowValid = false;
        if isfield(V, 'window') && ~isempty(V.window)
            try
                % Try to query window to see if it's still valid
                Screen('WindowKind', V.window);
                windowValid = true;
            catch
                windowValid = false;
            end
        end
        
        if windowValid
            % Close any remaining textures (if any exist)
            try
                % Screen('WindowKind') returns window pointers, but we'll just try to close
                % any remaining textures through the window if possible
                % Note: Individual texture closing is handled elsewhere
            catch
                % Ignore errors when closing textures
            end
            
            if Finished
                try
                    Screen('TextSize', V.window, 50);
                    DrawFormattedText(V.window, 'Experiment Complete!\n\nThank you for your participation.', 'center', V.windowRect(4)/2, [255, 255, 255]);
                    Screen('Flip', V.window);
                    WaitSecs(4);
                catch
                    % Window might have been closed, just skip display
                end
            else
                try
                    Screen('TextSize', V.window, 50);
                    DrawFormattedText(V.window, 'Terminating Experiment.', 'center', V.windowRect(4)/2, [255, 255, 255]);
                    Screen('Flip', V.window);
                    WaitSecs(1);
                catch
                    % Window might have been closed, just skip display
                end
            end
        else
            % Window already closed, just print message
            if Finished
                disp('Experiment Complete! Thank you for your participation.');
            else
                disp('Experiment terminated.');
            end
        end
    catch ME
        % If anything goes wrong, just print message and continue
        if Finished
            disp('Experiment Complete! Thank you for your participation.');
        else
            disp('Experiment terminated.');
        end
        disp(['Note: Error during cleanup: ', ME.message]);
    end
    
    % Always try to close everything
    try
        sca; %Screen('CloseAll');
    catch
        % Ignore errors when closing
    end
    
    close all;
    disp('Experiment Code Finished');
end

function [] = printScreen(filename, window)
    global V
    if V.PrintScreens
        saveDir = fullfile(getExperimentDataDir(), 'PrintScreen');
        if ~isfolder(saveDir)
            mkdir(saveDir);
        end
        if ~contains(filename,'.')
            filename = [filename '.png'];
        end
        img = Screen('GetImage', window);
        filename = fullfile(saveDir, filename);
        imwrite(img, filename);
    end
end

function [] = saveTrialStimulusSnap(win, trialIdx, segIdx, snapDir)
% Save the current stimulus display as a PNG for inspection.
% Called after Screen('Flip') so the image matches what was shown.
% trialIdx: trial number (1-based), segIdx: segment number (1-based).
    fname = sprintf('StimulusSnap_trial%03d_seg%02d.png', trialIdx, segIdx);
    fullpath = fullfile(snapDir, fname);
    try
        img = Screen('GetImage', win);
        imwrite(img, fullpath);
    catch ME
        warning('saveTrialStimulusSnap: failed to save %s: %s', fullpath, ME.message);
    end
end

% ===================== Noisy Stimuli Functions (from NoiseDemo_VMRand.m) =====================

function drawNoisySquareAt(V, hueDeg, noiseLevel, angleDeg, P, prePattern)
% Draw one B×B noisy square at a given polar angle (simplified version, no flip)
% noiseLevel: 'low' or 'high' (determines Von Mises kappa parameter)
% If prePattern is provided, reuse it (for replicas).

    if nargin < 6 || isempty(prePattern)
        [rgb01, ~] = makeNoisyPattern(V, hueDeg, noiseLevel, P, 1);
    else
        rgb01 = prePattern;  % reuse exact tiles/colors
    end

    % center position on the stimulus circle (matching coordinate system from Example_Sequential)
    th = deg2rad(angleDeg);
    cx = V.centerX + V.stim.positionradius * cos(th);
    cy = V.centerY - V.stim.positionradius * sin(th);  % Note: -sin for y-axis (screen coordinates)

    side   = round(V.square.side_px_full);
    B      = V.square.B;
    tilePx = round(V.square.tile_px);
    rect   = CenterRectOnPoint([0 0 side side], round(cx), round(cy));
    tileRects = buildTileRects(rect, B, tilePx);

    % Convert to appropriate color format
    if ~(isfield(V, 'useFloat') && V.useFloat)
        % Standard mode: convert 0-1 to 0-255
        rgb01 = rgb01 * 255;
    end

    Screen('FillRect', V.window, rgb01', tileRects);
end

function [rgb01, huesDeg] = makeNoisyPattern(V, hueDeg, noiseLevel, P, instanceId)
% Returns nTiles×3 double in [0,1] and nTiles×1 hue degrees
% instanceId: per-item index (1..N) so redundant same-hue items get different tile layouts.
    if nargin < 5 || isempty(instanceId)
        instanceId = 1;
    end
    B      = V.square.B;
    nTiles = B * B;

    % Get Von Mises kappa parameter based on noise level
    % Ensure noiseLevel is a char array for comparison
    if isstring(noiseLevel)
        noiseLevel = char(noiseLevel);
    end
    
    if strcmpi(noiseLevel, 'low')
        K = P.K_LowNoise;
    elseif strcmpi(noiseLevel, 'high')
        K = P.K_HighNoise;
    else
        % Debug output if noise level is unexpected
        warning('Unexpected noiseLevel: "%s" (class: %s). Using low noise.', noiseLevel, class(noiseLevel));
        K = P.K_LowNoise;
    end
    
    % Quantile-based Von Mises (deterministic multiset for mean-offset stats).
    huesDeg = sampleVonMisesQuantiles(hueDeg, K, nTiles, false);
    % Without spatial shuffle, quantiles are monotone → adjacent tiles have nearly
    % identical hues in row-major order → looks like a smooth gradient, not a 10×10 mosaic.
    huesDeg = shuffleHueTilesDeterministically(huesDeg, hueDeg, K, instanceId);

    % Convert each hue to RGB from your wheel
    rgb01 = wheelRGB01_fromDegrees(huesDeg, P.cMap360_255);   % n×3, 0..1
end

function [rgb01, huesDeg] = makeNoisyPatternRandom(V, hueDeg, noiseLevel, P, instanceId)
% Uses random sampling from Von Mises PDF; per-instance spatial scramble so layouts differ.
    if nargin < 5 || isempty(instanceId)
        instanceId = 1;
    end
    B      = V.square.B;
    nTiles = B * B;

    if strcmpi(noiseLevel, 'low')
        K = P.K_LowNoise;
    elseif strcmpi(noiseLevel, 'high')
        K = P.K_HighNoise;
    else
        warning('Unexpected noiseLevel: "%s". Using low noise.', noiseLevel);
        K = P.K_LowNoise;
    end

    huesDeg = sampleVonMisesDegrees(hueDeg, K, nTiles);
    huesDeg = shuffleHueTilesDeterministically(huesDeg, hueDeg, K, instanceId);
    rgb01 = wheelRGB01_fromDegrees(huesDeg, P.cMap360_255);   % n×3, 0..1
end

function [rgb01, huesDeg] = getPatternByMode(V, hueDeg, noiseLevel, P, instanceId)
% Returns pattern based on sampling mode. instanceId = item index within trial (1..N).
    if nargin < 5 || isempty(instanceId)
        instanceId = 1;
    end
    if isfield(P, 'samplingMode') && strcmpi(P.samplingMode, 'statistical')
        [rgb01, huesDeg] = makeNoisyPatternRandom(V, hueDeg, noiseLevel, P, instanceId);
    else
        [rgb01, huesDeg] = makeNoisyPattern(V, hueDeg, noiseLevel, P, instanceId);
    end
end

function meanOffset = calculateMeanOffset(huesDeg, targetHueDeg)
% Calculate mean offset from target using shortest angular distance
    offsets = mod(huesDeg - targetHueDeg + 180, 360) - 180;
    meanOffset = mean(offsets);
end

function targetHue = computeTargetHue(trial, stimStats)
% Determine target hue using sampled mean offsets
    if strcmp(trial.Condition{1}, 'Baseline')
        targetIdx = trial.Target;
        baseHue = stimStats.baseHues(targetIdx);
        meanOffset = stimStats.meanOffsets(targetIdx);
        targetHue = mod(baseHue + meanOffset, 360);
    else
        baseHue = stimStats.baseHues(1);
        meanOffset = mean(stimStats.meanOffsets(~isnan(stimStats.meanOffsets)));
        targetHue = mod(baseHue + meanOffset, 360);
    end
end

function targetHue = computeTargetHueFromArrays(condition, targetIdx, baseHues, meanOffsets)
% Determine target hue using precomputed arrays
    if strcmp(condition, 'Baseline')
        baseHue = baseHues(targetIdx);
        meanOffset = meanOffsets(targetIdx);
        targetHue = mod(baseHue + meanOffset, 360);
    else
        baseHue = baseHues(1);
        meanOffset = mean(meanOffsets(~isnan(meanOffsets)));
        targetHue = mod(baseHue + meanOffset, 360);
    end
end

function checkRedundantUniqueness(tileHues, P, trialIndex, usedPrecompute)
% Check that within a redundant set, no two tileHues are identical (after rounding).
% If P.AssertUniqueRedundant: error on duplicate; else: warn.
% If P.LogRedundantFingerprint: print fingerprints (mean, std, sum rounded hues).
    if nargin < 4
        usedPrecompute = []; %#ok<NASGU>
    end
    dupPairs = [];
    for a = 1:numel(tileHues)
        for b = (a+1):numel(tileHues)
            ha = round(tileHues{a});
            hb = round(tileHues{b});
            if isempty(ha) || isempty(hb)
                continue;
            end
            if isequal(ha, hb)
                dupPairs = [dupPairs; a, b]; %#ok<AGROW>
            end
        end
    end
    if isfield(P, 'LogRedundantFingerprint') && P.LogRedundantFingerprint
        for j = 1:numel(tileHues)
            h = tileHues{j};
            fprintf('Trial %d item %d: mean=%.2f std=%.2f sumRounded=%d\n', ...
                trialIndex, j, mean(h), std(h), sum(round(h)));
        end
    end
    if ~isempty(dupPairs)
        msg = sprintf('Duplicate redundant stimuli (trial %d, N=%d, precompute=%d). Pairs: %s', ...
            trialIndex, numel(tileHues), usedPrecompute, mat2str(dupPairs));
        if isfield(P, 'AssertUniqueRedundant') && P.AssertUniqueRedundant
            error('%s', msg);
        else
            warning('%s', msg);
        end
    end
end

function T = precomputeStimuli(T, P)
% Precompute tile patterns, mean offsets, base hues, and target hue
    global V
    n = height(T);
    for i = 1:n
        cols = T.Colors{i};
        cond = T.Condition{i};
        targetIdx = T.Target(i);
        nItems = numel(cols);
        tileRGB = cell(1, nItems);
        tileHues = cell(1, nItems);
        meanOffsets = nan(1, nItems);
        baseHues = cols;
        for k = 1:nItems
            [rgb01, huesDeg] = getPatternByMode(V, cols(k), T.NoiseLevel{i}, P, k);
            if strcmp(cond, 'Homo_Space') && isfield(P, 'samplingMode') && ...
               strcmpi(P.samplingMode, 'statistical')
                maxResample = 10;
                resampleCount = 0;
                while any(cellfun(@(h) isequal(round(h), round(huesDeg)), tileHues(1:k-1)))
                    [rgb01, huesDeg] = getPatternByMode(V, cols(k), T.NoiseLevel{i}, P, k);
                    resampleCount = resampleCount + 1;
                    if resampleCount >= maxResample
                        break;
                    end
                end
            end
            tileRGB{k} = rgb01;
            tileHues{k} = huesDeg;
            meanOffsets(k) = calculateMeanOffset(huesDeg, cols(k));
        end
        T.TileRGB{i} = tileRGB;
        T.TileHues{i} = tileHues;
        T.MeanOffsets{i} = meanOffsets;
        T.BaseHues{i} = baseHues;
        T.TargetHue(i) = computeTargetHueFromArrays(cond, targetIdx, baseHues, meanOffsets);
        if strcmp(cond, 'Homo_Space') && isfield(P, 'samplingMode') && strcmpi(P.samplingMode, 'statistical')
            checkRedundantUniqueness(tileHues, P, i, true);
        end
    end
end

function printTrialBalance(expTrials)
% Print counts by Condition × ItemN × NoiseLevel, and CueType (R vs NR)
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
    if ismember('NoiseLevel', expTrials.Properties.VariableNames)
        nl = string(expTrials.NoiseLevel);
        fprintf('By noise level: ');
        for n = 1:numel(noiseLevels)
            fprintf('%s=%d ', noiseLevels{n}, sum(nl == string(noiseLevels{n})));
        end
        fprintf('\n');
    end
    if ismember('CueType', expTrials.Properties.VariableNames)
        fprintf('\n--- CueType counts ---\n');
        ctStr = string(expTrials.CueType);
        cuesU = unique(ctStr, 'stable');
        for k = 1:numel(cuesU)
            fprintf('  %s: %d\n', cuesU(k), sum(ctStr == cuesU(k)));
        end
    end
    fprintf('\n');
end

function printStimulusChecks(expTrials, nShow)
% Print sample rows and basic checks for TargetHue/MeanOffsets/BaseHues
    fprintf('\n=== Stimulus Check (first %d trials) ===\n', nShow);
    rows = min(nShow, height(expTrials));
    disp(expTrials(1:rows, {'Condition','ItemN','NoiseLevel','Target','TargetHue','MeanOffsets','BaseHues'}));
    lenOK = all(cellfun(@numel, expTrials.MeanOffsets(1:rows)) == expTrials.ItemN(1:rows)) && ...
            all(cellfun(@numel, expTrials.BaseHues(1:rows)) == expTrials.ItemN(1:rows));
    fprintf('MeanOffsets/BaseHues length OK: %d\n\n', lenOK);
end

function cmap = buildColorMapNoPTB()
% Build OKLab color wheel map without PTB
    L = 0.85;
    radius = 0.23;
    increments = 360 * 7;
    angles = 0 : 2*pi/increments : 2*pi;
    map = zeros(numel(angles), 3);
    map(:,2:3) = radius * [cos(angles') sin(angles')];
    map(:,1) = L;
    map(end,:) = [];
    rgbLin = okLab2linSRGB(map);
    rgb = lin2srgb(rgbLin);
    rgb = max(min(rgb,1),0);
    cmap = rgb * 255;
end

function tileRects = buildTileRects(outerRect, B, tilePx)
% Returns 4×(B*B) rects for Screen('FillRect', window, colors, rects)
    x0 = round(outerRect(1)); y0 = round(outerRect(2));
    x1 = round(outerRect(3)); y1 = round(outerRect(4));
    sidePx = min(x1 - x0, y1 - y0);

    % Keep integer geometry stable across positions. A floating-point underflow
    % here can make tilePx drop by 1 (e.g., 5->4), shrinking one whole square.
    tilePx = max(1, round(tilePx));
    maxTilePx = max(1, floor(sidePx / B));
    tilePx = min(tilePx, maxTilePx);
    padPx  = floor((sidePx - B*tilePx) / 2);
    x0     = x0 + padPx;  y0 = y0 + padPx;

    tileRects = zeros(4, B*B);
    k = 1;
    for r = 0:B-1
        for c = 0:B-1
            xL = round(x0 + c*tilePx);
            yT = round(y0 + r*tilePx);
            tileRects(:,k) = [xL; yT; xL + tilePx; yT + tilePx];
            k = k + 1;
        end
    end
end

function rgb01 = wheelRGB01_fromDegrees(deg, cMap360_255)
% deg: 1×N or N×1 degrees 0..359
    idx = round(mod(deg, 360)); idx(idx==0) = 360;   % map 0→360th row
    rgb01 = double(cMap360_255(idx, :)) / 255;       % N×3 in [0,1]
end

function huesDeg = sampleVonMisesQuantiles(muDeg, kappa, n, doShuffle)
% Sample from Von Mises distribution using quantile-based inverse transform sampling.
% Deterministic mode: use doShuffle=false so same (muDeg, kappa, n) yields same pattern.
%
% METHOD: Quantile-Based Inverse Transform Sampling
% 1. Generate n uniform quantiles: [0.5/n, 1.5/n, ..., (n-0.5)/n]
% 2. Map each quantile to an angle using inverse Von Mises CDF
% 3. If doShuffle (default true): shuffle to avoid spatial clustering
%
% Inputs:
%   muDeg, kappa, n: as below
%   doShuffle (optional, default true): if false, same inputs give same tile order (for deterministic mode)
    if nargin < 4
        doShuffle = true;
    end

    if kappa < 1e-8
        % Effectively uniform: sample uniformly around circle
        huesDeg = mod(muDeg + (rand(1,n) - 0.5) * 360, 360);
        return;
    end

    % Generate uniform quantiles (centered quantiles for better coverage)
    quantiles = ((1:n) - 0.5) / n;  % [0.5/n, 1.5/n, ..., (n-0.5)/n]

    % Map quantiles to angles using inverse Von Mises CDF
    huesDeg = vonMisesQuantile(muDeg, kappa, quantiles);

    if doShuffle
        huesDeg = huesDeg(randperm(n));
    end
end

function huesDeg = shuffleHueTilesDeterministically(huesDeg, muDeg, kappa, instanceId)
% Permute tile hues spatially; multiset unchanged (same mean offset). instanceId
% (item index 1..N) makes redundant same-hue stimuli use different pixel layouts.
    if nargin < 4 || isempty(instanceId)
        instanceId = 1;
    end
    n = numel(huesDeg);
    seed = mod(round(mod(muDeg, 360)) * 7919 + round(kappa * 1e6) + n * 97 + instanceId * 104729, 2^31 - 2);
    if seed < 1
        seed = 1;
    end
    rs = RandStream('mt19937ar', 'Seed', seed);
    p = randperm(rs, n);
    huesDeg = huesDeg(p);
end

function huesDeg = sampleVonMisesDegrees(muDeg, kappa, n)
% Sample from von Mises distribution using rejection sampling
    mu = deg2rad(muDeg);
    if kappa < 1e-8
        huesDeg = rand(1, n) * 360;
        return;
    end

    a = 1 + sqrt(1 + 4*kappa^2);
    b = (a - sqrt(2*a)) / (2*kappa);
    r = (1 + b^2) / (2*b);

    out = zeros(1, n);
    i = 1;
    attempts = 0;
    maxAttempts = 2000;

    while i <= n
        U1 = rand;
        z = cos(pi * U1);
        f = (1 + r*z) / (r + z);
        c = kappa * (r - f);
        U2 = rand;
        attempts = attempts + 1;

        if attempts > maxAttempts
            out(i) = mu + (rand*2*pi - pi);
            i = i + 1;
            attempts = 0;
            continue;
        end

        if U2 < c*(2 - c) || U2 <= c*exp(1 - c)
            U3 = rand;
            f = max(min(f, 1), -1);
            theta = acos(f);
            if U3 > 0.5
                theta = -theta;
            end
            out(i) = mu + theta;
            i = i + 1;
            attempts = 0;
        end
    end

    out = angle(exp(1i*out));
    huesDeg = mod(rad2deg(out), 360);
end

function anglesDeg = vonMisesQuantile(muDeg, kappa, quantiles)
% Compute quantiles of Von Mises distribution using inverse CDF
% Uses precomputed CDF table for efficiency
%
% Inputs:
%   muDeg: mean direction in degrees (0-360)
%   kappa: concentration parameter
%   quantiles: vector of quantile values in [0, 1]
%
% Output:
%   anglesDeg: quantile angles in degrees (0-360)

    persistent cdfTable kappaTable angleRangeTable

    % Precompute CDF table if not already done (cached for performance)
    if isempty(cdfTable) || isempty(kappaTable)
        % Build CDF lookup table for common kappa values
        nAngles = 2000;  % Resolution: 0.18° per bin
        angleRangeRad = linspace(-pi, pi, nAngles);
        kappaList = [0.5, 1, 2, 3, 5, 10, 20, 30, 50, 100];  % Common kappa values
        
        kappaTable = kappaList;
        cdfTable = zeros(length(kappaList), nAngles);
        angleRangeTable = rad2deg(angleRangeRad);
        
        for ki = 1:length(kappaList)
            k = kappaList(ki);
            % Compute CDF: F(θ) = ∫[-π to θ] f(φ) dφ
            I0 = besseli(0, k);
            pdfVals = exp(k * cos(angleRangeRad)) / (2*pi*I0);
            
            % Numerically integrate PDF to get CDF
            dTheta = angleRangeRad(2) - angleRangeRad(1);
            cdfVals = zeros(size(pdfVals));
            cdfVals(1) = 0;  % CDF at -π is 0
            for i = 2:nAngles
                cdfVals(i) = cdfVals(i-1) + (pdfVals(i-1) + pdfVals(i))/2 * dTheta;
            end
            % Normalize to [0,1] (CDF at +π should be 1)
            cdfVals = cdfVals / cdfVals(end);
            cdfTable(ki, :) = cdfVals;
        end
    end

    % Find closest kappa in table
    if kappa <= kappaTable(1)
        ki = 1;
    elseif kappa >= kappaTable(end)
        ki = length(kappaTable);
    else
        [~, ki] = min(abs(kappaTable - kappa));
    end

    % Get CDF for this kappa
    cdfVals = cdfTable(ki, :);
    angleRange = angleRangeTable;

    % For each quantile, find corresponding angle via inverse CDF
    anglesDeg = zeros(size(quantiles));
    for i = 1:length(quantiles)
        q = quantiles(i);
        idx = find(cdfVals >= q, 1, 'first');
        if isempty(idx)
            anglesDeg(i) = angleRange(end);
        elseif idx == 1
            anglesDeg(i) = angleRange(1);
        else
            % Linear interpolation between bracketing CDF values
            qLow = cdfVals(idx-1);
            qHigh = cdfVals(idx);
            if abs(qHigh - qLow) < 1e-10
                anglesDeg(i) = angleRange(idx);
            else
                t = (q - qLow) / (qHigh - qLow);
                anglesDeg(i) = angleRange(idx-1) + t * (angleRange(idx) - angleRange(idx-1));
            end
        end
    end

    % Convert to absolute angles and wrap to [0, 360)
    anglesDeg = mod(muDeg + anglesDeg, 360);
end
