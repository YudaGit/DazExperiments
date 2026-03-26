%======================================================================
% Exp2a_SeqSingle_Final.m   (Continuous colour-report) Version.28102025
% Daz Liu 2025 PhD Experiment 2, Sequential 3 way
%
%
%======================================================================

clear; close all; clc;
% Force cleanup of any existing windows
try
    sca; Screen('CloseAll');
    WaitSecs(0.2);  % Give time for cleanup
catch
    % Ignore errors during cleanup
end
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

% Global & PTB window
global V
global P  % Noise parameters for noisy stimuli
V = initiate();             % your existing helper: opens window & sets V
win = V.window;

% Validate window was created successfully
if ~isWindowValid(win)
    error('Failed to create valid PTB window. Please check your display setup.');
end

V.PrintScreens = false;     % don't save screenshots by default


% Design specification for Pilot 1: Main Redundancy Integration
design.ItemNList    = [4 6];           % Set sizes: N=4, N=6
design.NoiseLevels  = {'high'};        % Only high noise for Pilot 1
design.BaselineReps = 15;              % trials per set size (Baseline)
design.RSReps       = 30;              % trials per set size per RS condition (R-cue + NR-cue)
design.GroupedReps  = 30;              % trials per set size (40 R-cue + 40 NR-cue)
design.PracticeReps = 0;               % No practice trials
design.presDur      = 0.30;
design.retDur       = 1.0;
design.SegmentDur   = 0.30;
design.ISI          = 0.15;

% Generate practice & main tables
[pracTrials, expTrials] = TrialMatrixSeq3way_STInte(design, sessionN, participantID, age, timestamp);

% Calibration & textures
VA5deg        = calibrateMonitor();
adjustSquareStim(VA5deg);  % Use square stimulus adjustment for noisy squares
wheelTex      = DrawWheel();
neutralTex    = DrawNeutralWheel();

% Noise parameters for Pilot 1 (high noise only)
% Pilot 1 uses only high noise (K < 2) as specified in design
P.K_LowNoise      = 25;       % Not used in Pilot 1, but kept for compatibility
P.K_HighNoise     = 0.8;        % High noise for Pilot 1 (matches demo)
                                % Lower kappa = wider spread around target
% Prepare color map for noisy stimuli (360-row lookup)
if size(V.color.map,1) == 360
    P.cMap360_255 = V.color.map;
else
    idx = round(linspace(1, size(V.color.map,1), 360));
    P.cMap360_255 = V.color.map(idx, :);
end

try
    % Main instructions (skip practice for pilot)
    instructions(3);

    % — Main Loop —
    for ii = 1:height(expTrials)
        tr = expTrials(ii,:);
    
        % Verify window is still valid before proceeding
        if ~isWindowValid(win)
            error('Window is no longer valid at trial %d. Experiment terminated.', ii);
        end
    
        % Start of trial: only fixation (no location indicators)
        safeFillRect(win, V.patch.bg);
        fixation(0);
        safeFlip(win);
        WaitSecs(V.Durations.FixationDuration); 
        
        % Track which locations have been shown (and will be masked)
        shownLocations = [];
        
        % 1) Presentation sequence (simultaneous: single segment with all items, sequential: multiple segments)
        allSegs = tr.SegmentOrder{1};                 % cell array: {1:N} for simultaneous, {1},{2},... for sequential
        locs = tr.StimulusLocations{1};
        
        for seg = 1:numel(allSegs)
            idxList = allSegs{seg};                   % numeric vector (1×1 for singletons)
        
            try
                % Show stimulus with existing masks
                safeFillRect(win, V.patch.bg);
                fixation(0);
                % Draw masks for previously shown locations
                if ~isempty(shownLocations)
                    DrawMasksAtLocations(shownLocations);
                end
                DrawStimulusSegment(tr, idxList);         % now handles vector or scalar
                safeFlip(win);
                
                % CRITICAL: Each segment must get full SegmentDur, regardless of location
                segmentStartTime = GetSecs();
                WaitSecs(design.SegmentDur);
                segmentEndTime = GetSecs();
                actualSegmentDur = segmentEndTime - segmentStartTime;
                
                % Verify timing (debug - can be removed later)
                if abs(actualSegmentDur - design.SegmentDur) > 0.01
                    fprintf('Warning: Segment %d actual duration (%.3f s) differs from expected (%.3f s)\n', ...
                        seg, actualSegmentDur, design.SegmentDur);
                end
            catch ME
                % If there's an error during presentation, log it and continue
                fprintf('Error during segment %d presentation: %s\n', seg, ME.message);
                fprintf('Stack trace:\n');
                for k = 1:length(ME.stack)
                    fprintf('  File: %s, Line: %d, Function: %s\n', ...
                        ME.stack(k).file, ME.stack(k).line, ME.stack(k).name);
                end
                rethrow(ME);  % Re-throw to be caught by outer try-catch
            end
        
            % Track locations shown in this segment
            for k = idxList
                angleDeg = locs(k);
                if ~ismember(angleDeg, shownLocations)
                    shownLocations = [shownLocations, angleDeg];
                end
            end
            
            % Immediately replace stimulus with mask
            safeFillRect(win, V.patch.bg);
            fixation(0);
            DrawMasksAtLocations(shownLocations);  % Draw all masks for shown locations
            safeFlip(win);
            
            % CRITICAL: ISI must be applied between ALL segments (except last)
            % This ensures equal timing between segments, even for same-location R items
            if seg < numel(allSegs)
                isiStartTime = GetSecs();
                WaitSecs(design.ISI);
                isiEndTime = GetSecs();
                actualISI = isiEndTime - isiStartTime;
                
                % Verify ISI timing (debug - can be removed later)
                if abs(actualISI - design.ISI) > 0.01
                    fprintf('Warning: ISI after segment %d actual duration (%.3f s) differs from expected (%.3f s)\n', ...
                        seg, actualISI, design.ISI);
                end
            end
        end
        
        % 2) Final retention (fixation + all masks)
        safeFillRect(win, V.patch.bg);
        fixation(0);
        DrawMasksAtLocations(shownLocations);  % Masks serve as location indicators
        safeFlip(win);
        WaitSecs(tr.retDur);  

        % 5) Response
        [ expTrials.MouseX{ii}, expTrials.MouseY{ii}, ...
          expTrials.MouseAngles{ii}, expTrials.MouseDistances{ii}, ...
          expTrials.MouseTime{ii}, expTrials.ResponseTime(ii), ...
          expTrials.ResponseAngle(ii), expTrials.DerotatedResponseAngle(ii), ...
          expTrials.Precision(ii) ] = ...
            GetResponse(tr, wheelTex);

        % 6) Speed check & feedback
        [ expTrials.MouseInitTooSlow(ii), expTrials.MouseInitTooFast(ii), ...
          expTrials.TrialTooSlow(ii) ] = speedCheck(expTrials(ii,:));
        DrawWheelFeedback(expTrials(ii,:), wheelTex);
        penalty  = expTrials.TrialTooSlow(ii)*V.Durations.FeedbackPenaltyDuration;
        standard = ~expTrials.TrialTooSlow(ii)*V.Durations.FeedbackDuration;
        WaitSecs(penalty+standard);

        % 7) Inter‐trial feedback
        DrawIntertrialFeedbackFast( expTrials(1:ii,:), win, V.windowRect, height(expTrials) );
    end

    % ----------------------------
    % Save and finish
    % ----------------------------
    SaveData(expTrials, sessionN, participantID, timestamp);
    ExperimentEnd(true);

catch ME
    disp('An error occurred:'); disp(ME.message);
    ExperimentEnd(false);
end


% Display Functions
%========================================================
function drawRings(tr)
    % Draw 6 fixed square location indicators (always 6, regardless of set size)
    % Squares are 1.1x larger than the stimulus squares
    global V
    numLocations = 6;  % Always show 6 location indicators
    baseAngle = 90;    % Start at 12 o'clock (90 degrees), no rotation
    
    % Calculate square indicator size (1.1x larger than stimulus)
    indicatorSize = V.square.side_px_full * 1.1;
    halfSize = indicatorSize / 2;
    
    % Fixed positions: evenly spaced around circle, starting at 12 o'clock
    for j = 1:numLocations
        angleDeg = baseAngle + (j-1) * (360/numLocations);
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
    % allow {idx} or idx
    if iscell(idx), idx = idx{1}; end
    idx = idx(:)';                      % row

    locs = trial.StimulusLocations{1};
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
    
    % Debug: Print noise level (TEMPORARY - remove after verification)
    % Uncomment the next line to see noise levels being used
    fprintf('DrawStimulusSegment: NoiseLevel = "%s"\n', noiseLevel);

    % All stimuli in this segment use the same noise level (trial-level property)
    for k = idx
        targetHueDeg = cols(k);
        angleDeg = locs(k);
        
        % Generate noisy pattern
        [rgb01, ~] = makeNoisyPattern(V, targetHueDeg, noiseLevel, P);
        
        % Draw noisy square at location
        drawNoisySquareAt(V, targetHueDeg, noiseLevel, angleDeg, P, rgb01);
    end
end

% Instruction
function [] = instructions(n)
% Display of multiple instructions (n), Next = Mouse Click (L)
% Can set position and text size
    global V
    m = .25;
    if n == 1
        inst = ['Welcome to the colour-report task.\n\n\n' ...
                    'In each trial, the screen will show six color circles.\n' ...
                    'Please try to remember all colors.\n' ...
                    'Report the color of the cued target \n' ...
                    'using the mouse and the response color wheel'];
    elseif n == 2
        inst = ['Practice block:\n\n\n' ...
            'You can experience random stimulus display durations\n' ...
            'with these practice trials.\n\n' ...
            'You can choose to go without practice trials in later sessions\n' ...
            'by informing the experimenter.\n\n' ...
            'Practice data will not contribute to main data']; 
    elseif n == 3
        inst =['Main block:\n\n' ...
            'These are the main experimental trials. \n\n' ...
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
    safeFlip(V.window);
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
    safeFillRect(winPtr, [128 128 128]);

    % DRAW FIXATION USING EXISTING FUNCTION
    fixation(0);

    % DRAW BARS
    for i = 1:nDone
        err   = abs(trialsSoFar.Precision(i));
        score = 1 - min(err / 180, 1);    % normalized 0..1
        hPx   = round(score * plotH);
        xLeft = leftMargin + (i) * (barW + spaceW);
        rect  = [xLeft, bottomY - hPx, xLeft + barW, bottomY];
        safeFillRect(winPtr, barColor, rect);
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
    safeFlip(winPtr);
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
        targetAngle = deg2rad(mod(trial.Colors{1}(trial.Target) + V.color.rotation, 360));

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
    safeFlip(V.window);
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
v.Durations.StimulusDuration       = [0.10 0.15 0.20 0.25 0.30 0.35];
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
    targetAngle = trial.StimulusLocations{1}(trial.Target);
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
        safeFlip(V.window);
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
    try
        % Check if window is valid before proceeding
        if ~isfield(V, 'window') || isempty(V.window)
            return;  % Window not available, skip drawing
        end
        
        % Verify window is still valid
        try
            Screen('WindowKind', V.window);
        catch
            return;  % Window invalid, skip drawing
        end
        
        theta = deg2rad(angleDeg);
        centerX = round(V.centerX + V.stim.positionradius * cos(theta));
        centerY = round(V.centerY - V.stim.positionradius * sin(theta));  % Note: -sin for y-axis (screen coordinates)
        squareSize = V.square.side_px_full;
        maskRect = CenterRectOnPointd([0, 0, squareSize, squareSize], centerX, centerY);
        
        noiseMaskTex = GaussianTextureSquare();  % Returns cached texture (never closed)
        
        % Verify texture is valid before drawing
        if isempty(noiseMaskTex) || noiseMaskTex <= 0
            return;  % Invalid texture, skip drawing
        end
        
        % Verify texture is still valid
        try
            Screen('WindowKind', noiseMaskTex);
        catch
            % Texture was closed, try to recreate it
            try
                noiseMaskTex = GaussianTextureSquare();
                if isempty(noiseMaskTex) || noiseMaskTex <= 0
                    return;  % Failed to recreate, skip drawing
                end
            catch
                return;  % Failed to recreate texture, skip drawing
            end
        end
        
        % Draw texture
        Screen('DrawTexture', V.window, noiseMaskTex, [], maskRect);
        
    catch ME
        % Silently skip if there's an error - don't crash the experiment
        % Window or texture might be invalid, which is okay during cleanup
    end
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
    locs = trial.StimulusLocations{1};
    DrawMasksAtLocations(locs);
end

function Mask(trial)
    % Legacy function - kept for compatibility
    global V
    for ii = 1:trial.ItemN
        noiseMaskTex = GaussianTexture;
        theta = deg2rad(trial.StimulusLocations{1}(ii));
        centerX = V.centerX + V.stim.positionradius * cos(theta);
        centerY = V.centerY - V.stim.positionradius * sin(theta);
        basePedestal = [0, 0, V.stim.pedestalradius * 2, V.stim.pedestalradius * 2];
        centeredPedestal = CenterRectOnPointd(basePedestal, centerX, centerY);
        Screen('FillOval', V.window, V.cue.Bgcolor, centeredPedestal);
        Screen('DrawTexture', V.window, noiseMaskTex, [], centeredPedestal);
        Screen('Close', noiseMaskTex);
    end
    fixation(0);
    safeFlip(V.window);
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
        safeFlip(V.window);
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
            safeFlip(V.window);
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
    safeFillRect(V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    if trial.CuedFeature_i == false
        Screen('DrawTexture', V.window, wheelTexture, [], [], V.color.rotation);
    else
        Screen('DrawTexture', V.window, orientationTexture);
    end
    fixation(0);
    %Cue(trial, true, false, false)
    TargetCue(trial, false);
    safeFlip(V.window);
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
                if precision > 180; precision = precisiopositionradiusn - 360; end

            else
                responseangle = mod(angles(end) - V.color.rotation, 360);
                derotatedAngle = mod( responseangle - trial.WheelRotation, 360 );
                precision = trial.Colors{1}(trial.Target) - responseangle;
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

function [] = SaveData(expTrials, sessionN, participantID, timestamp)
% Saving data for Pilot 1: Main Redundancy Integration (Space-Time)
    global V
    saveDir = 'Noise Pilot STInte Data';
    if ~isfolder(saveDir)
        mkdir(saveDir);
        disp(['Save Data Directory Created: ', saveDir]);
    end
    fname = sprintf('STInte_%s_sess%d_%s.mat', ...
                    participantID, sessionN, timestamp);
    fullpath = fullfile(saveDir, fname);
    try
        save(fullpath, 'expTrials', 'V');
        fprintf('✔ Data saved to:\n  %s\n', fullpath);
    catch ME
        warning('Failed to save data: %s\nError message:\n%s', ...
                fullpath, ME.message);
    end
     disp(['Data File: ', fname ' saved in directory ', saveDir]);
end


% Global Functions
% ========================================================
function v = initiate() %Global variable with hard-coded defaults.

% Force cleanup of any existing windows
try
    sca;                   
    Screen('CloseAll');    
    WaitSecs(0.5);
catch
    % Ignore errors during cleanup - windows may already be closed
end

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

% Validate window was created successfully
if ~isWindowValid(v.window)
    error('Failed to create valid PTB window. Please check your display setup.');
end

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
    if isWindowValid(v.window)
        Screen('FillRect', v.window, [v.patch.bg, v.patch.bg, v.patch.bg]);
        Screen('Flip', v.window);
        WaitSecs(0.1);
    end

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
            ['Align these two lines with the edges of your credit card.\n\nUse LEFT/RIGHT ' ...
            'arrow keys to move each line.\nUse UP/DOWN arrow keys to choose which line' ...
            ' moves.\nPress ENTER when done.'], ...
            'center', 'center', [255 255 255]);
        safeFlip(V.window);
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
                elseif any( [keyCode(KbName('Return')), keyCode(KbName('Return')+1)])
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
            safeFlip(V.window);
            WaitSecs(0.01);
    
        end
        blank(0);
        measured = rightLineX - leftLineX;
        CreditCardWith = 85.60;
        pixelsPerMm = measured / CreditCardWith;
        viewingdistance = 600; % 60cm
        desiredAngleDeg = 5; % 5 degree visual angle
        stim_in_mm = 2 * viewingdistance * tan((desiredAngleDeg / 2) * (pi/180));
        fiveDegVA_in_pixels = round( stim_in_mm * pixelsPerMm );

        savedConfig = currentConfig; 
        calibrationData = fiveDegVA_in_pixels; 
        save('screenCalibration.mat', 'savedConfig', 'calibrationData');
    end

end

function [] = adjustSquareStim(VA5deg)
% ADJUSTSQUARESTIM  VA-based geometry for upright square stimuli.
% - Squares are axis-aligned (no rotation).
% - Stimulus CENTERS lie on the 5° circle (radius = VA5deg/2).

    global V

    % ---- Validate inputs ----
    if ~isfield(V,'window') || isempty(V.window) || ~Screen('WindowKind', V.window)
        error('adjustSquareStim:InvalidWindow','V.window is not a valid PTB window.');
    end
    if ~isscalar(VA5deg) || ~isfinite(VA5deg) || VA5deg<=0
        error('adjustSquareStim:InvalidVA5','VA5deg must be a positive finite scalar (pixels).');
    end

    % ---- px/deg & the center-path radius (5° circle) ----
    V.pxPerDeg               = VA5deg / 5;                  % px per 1°
    V.layout.centerRadiusPx  = max(1, round(VA5deg/2));     % = 2.5° in px

    % ---- Derive other geometry (scaled from your originals) ----
    degpx = V.pxPerDeg;
    V.feedback.linewidth   = max(1, round(degpx * .08));
    V.feedback.ticklength  = round(degpx * .50);

    V.annulus.radiusOuter  = round(degpx * 4.75);
    V.annulus.radiusInner  = round(degpx * 4.25);

    V.stim.positionradius  = round(degpx * 1.82);   % position radius for stimulus locations

    % ---- Square stimulus spec (upright) ----
    V.square.R_deg         = 0.80;      % inscribing circle radius in deg (≈ your 0.8° size)
    V.square.coverage_c    = 1.00;      % 1.00 => corners touch the inscribing circle
    V.square.B             = 10;       % B×B tiles (10×10 grid)

    side_deg_full          = V.square.coverage_c * sqrt(2) * V.square.R_deg;
    side_px_full           = max(V.square.B, round(side_deg_full * V.pxPerDeg));
    side_px_full           = side_px_full - mod(side_px_full, V.square.B);  % divisible by B
    V.square.side_px_full  = max(V.square.B, side_px_full);
    V.square.tile_px       = V.square.side_px_full / V.square.B;
    
    % Keep pedestal settings for compatibility
    V.stim.pedestalradius = round(degpx * .56 * 1.3);  % approximate pedestal size
    V.stim.pedestalcolor = [0, 0, 0];
    V.stim.radius = round(degpx * .56);  % keep for compatibility

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
end

function [] = blank(duration)
    global V
    safeFillRect(V.window, [V.patch.bg, V.patch.bg, V.patch.bg]);
    safeFlip(V.window);
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
                % Use WindowKind which is safer than Rect
                kind = Screen('WindowKind', V.window);
                if kind == 1  % 1 = onscreen window, 0 = offscreen window/texture
                    windowValid = true;
                end
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
                    % Try each Screen call individually with error suppression
                    try
                        Screen('TextSize', V.window, 50);
                    catch
                        % Window invalid, skip rest
                        return;
                    end
                    try
                        DrawFormattedText(V.window, 'Experiment Complete!\n\nThank you for your participation.', 'center', V.windowRect(4)/2, [255, 255, 255]);
                        safeFlip(V.window);
                        WaitSecs(4);
                    catch
                        % Window might have been closed during display, just skip
                    end
                catch
                    % Window might have been closed, just skip display
                end
            else
                try
                    % Try each Screen call individually with error suppression
                    try
                        Screen('TextSize', V.window, 50);
                    catch
                        % Window invalid, skip rest
                        return;
                    end
                    try
                        DrawFormattedText(V.window, 'Terminating Experiment.', 'center', V.windowRect(4)/2, [255, 255, 255]);
                        safeFlip(V.window);
                        WaitSecs(1);
                    catch
                        % Window might have been closed during display, just skip
                    end
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

function isValid = isWindowValid(winPtr)
% Helper function to check if a window pointer is valid
    isValid = false;
    if isempty(winPtr) || winPtr <= 0
        return;
    end
    try
        kind = Screen('WindowKind', winPtr);
        isValid = (kind == 1);  % 1 = onscreen window
    catch
        isValid = false;
    end
end

function safeFlip(winPtr, varargin)
% Safely call Screen('Flip') with error handling
% Returns silently if window is invalid (allows graceful degradation)
    if ~isWindowValid(winPtr)
        % Window is invalid - silently return instead of crashing
        fprintf('Warning: Window is not valid. Skipping Screen Flip.\n');
        return;
    end
    try
        Screen('Flip', winPtr, varargin{:});
    catch ME
        % If flip fails, log but don't crash - window might have been closed
        fprintf('Warning: Screen Flip failed: %s\n', ME.message);
        % Don't rethrow - allow experiment to continue if possible
    end
end

function safeFillRect(winPtr, color, rect)
% Safely call Screen('FillRect') with error handling
% Returns silently if window is invalid (allows graceful degradation)
    if ~isWindowValid(winPtr)
        % Window is invalid - silently return instead of crashing
        fprintf('Warning: Window is not valid. Skipping Screen FillRect.\n');
        return;
    end
    try
        if nargin < 3
            Screen('FillRect', winPtr, color);
        else
            Screen('FillRect', winPtr, color, rect);
        end
    catch ME
        % If FillRect fails, log but don't crash - window might have been closed
        fprintf('Warning: Screen FillRect failed: %s\n', ME.message);
        % Don't rethrow - allow experiment to continue if possible
    end
end

function [] = printScreen(filename, window)
    global V
    if V.PrintScreens
        saveDir = 'PrintScreen';
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

% ===================== Noisy Stimuli Functions (from NoiseDemo_VMRand.m) =====================

function drawNoisySquareAt(V, hueDeg, noiseLevel, angleDeg, P, prePattern)
% Draw one B×B noisy square at a given polar angle (simplified version, no flip)
% noiseLevel: 'low' or 'high' (determines Von Mises kappa parameter)
% If prePattern is provided, reuse it (for replicas).

    if nargin < 6 || isempty(prePattern)
        [rgb01, ~] = makeNoisyPattern(V, hueDeg, noiseLevel, P);
    else
        rgb01 = prePattern;  % reuse exact tiles/colors
    end

    % center position on the stimulus circle (matching coordinate system from Example_Sequential)
    th = deg2rad(angleDeg);
    cx = V.centerX + V.stim.positionradius * cos(th);
    cy = V.centerY - V.stim.positionradius * sin(th);  % Note: -sin for y-axis (screen coordinates)

    side   = V.square.side_px_full;
    B      = V.square.B;
    tilePx = V.square.tile_px;
    rect   = CenterRectOnPointd([0 0 side side], cx, cy);
    tileRects = buildTileRects(rect, B, tilePx);

    % Convert to appropriate color format
    if ~(isfield(V, 'useFloat') && V.useFloat)
        % Standard mode: convert 0-1 to 0-255
        rgb01 = rgb01 * 255;
    end

    safeFillRect(V.window, rgb01', tileRects);
end

function [rgb01, huesDeg] = makeNoisyPattern(V, hueDeg, noiseLevel, P)
% Returns nTiles×3 double in [0,1] and nTiles×1 hue degrees
% noiseLevel: 'low' or 'high' (determines Von Mises kappa parameter)
% Uses quantile-based sampling for consistent variance
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
    
    % Debug: Print K value (TEMPORARY - uncomment to verify)
    % Uncomment the next line to see K values being used
     fprintf('makeNoisyPattern: noiseLevel="%s", K=%.1f (should be 50 for low, 2 for high)\n', noiseLevel, K);

    % Sample hues using quantile-based Von Mises (no truncation needed)
    huesDeg = sampleVonMisesQuantiles(hueDeg, K, nTiles);

    % Convert each hue to RGB from your wheel
    rgb01 = wheelRGB01_fromDegrees(huesDeg, P.cMap360_255);   % n×3, 0..1
end

function tileRects = buildTileRects(outerRect, B, tilePx)
% Returns 4×(B*B) rects for Screen('FillRect', window, colors, rects)
    x0 = outerRect(1); y0 = outerRect(2); x1 = outerRect(3); y1 = outerRect(4);
    side = min(x1 - x0, y1 - y0);

    tilePx = floor(min(tilePx, side / B));
    pad    = (side - B*tilePx) / 2;
    x0     = x0 + pad;  y0 = y0 + pad;

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

function huesDeg = sampleVonMisesQuantiles(muDeg, kappa, n)
% Sample from Von Mises distribution using quantile-based inverse transform sampling
% This ensures consistent variance across trials and eliminates rejection sampling inefficiency
% 
% METHOD: Quantile-Based Inverse Transform Sampling
% 1. Generate n uniform quantiles: [0.5/n, 1.5/n, 2.5/n, ..., (n-0.5)/n]
% 2. Map each quantile to an angle using inverse Von Mises CDF
% 3. Shuffle to avoid spatial clustering in the grid
%
% Inputs:
%   muDeg: target hue in degrees (0-360)
%   kappa: concentration parameter (high = narrow distribution)
%   n: number of samples to generate
%
% Output:
%   huesDeg: n×1 vector of hue values in degrees (0-360)

    if kappa < 1e-8
        % Effectively uniform: sample uniformly around circle
        huesDeg = mod(muDeg + (rand(1,n) - 0.5) * 360, 360);
        return;
    end

    % Generate uniform quantiles (centered quantiles for better coverage)
    quantiles = ((1:n) - 0.5) / n;  % [0.5/n, 1.5/n, ..., (n-0.5)/n]

    % Map quantiles to angles using inverse Von Mises CDF
    huesDeg = vonMisesQuantile(muDeg, kappa, quantiles);

    % Shuffle to avoid spatial clustering in grid
    huesDeg = huesDeg(randperm(n));
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
