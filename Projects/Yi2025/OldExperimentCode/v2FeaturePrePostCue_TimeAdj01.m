% 2025 Honors Experiment
% A Continous Report Recall Task w/ Pre-Cue or Post-Probe Colored Triangles
% Dr. Paul M. Garrett
% The University of Melbourne
% Copyright Share-share-alike
% Start Date: 08-04-2025
% Edited: 17-04-2025

clear; close all; clc;
format shortg
KbName('UnifyKeyNames');

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
participantID = input('Enter Participant ID: ', 's');
sessionN = str2double(input('Enter Session Number (1 - 10): ', 's'));
age = str2double(input('Enter Age Number (17 - 99): ', 's'));
gender = str2double(input('Enter Gender (0 = M, 1 = W, 2 = O): ', 's'));

if isnan(gender) || isnan(age) || isnan(sessionN) || ...
        isempty(participantID) || (gender > 2 || gender < 0) || ...
        (age < 17 || age > 99) || (sessionN < 0 || sessionN > 10)
    fprintf('\nERROR: Enter correct participant details.\n\n')
    ExperimentEnd(false);
end

global Visual
Visual = initiate();
trials = TrialMatrix(360, sessionN, participantID, age, timestamp); % 360/12 = 30 trials per conditional permutation
practrials = TrialMatrix(13, sessionN, participantID, age, timestamp); % 13 = 24 trials after permutation correction


% For Yi to change:
% Stimulus druations (search "StimulusDurations")
% Mouse Too fast and Slow Durations (search "mouse timing")
% 'left-ctrl' + 'L' to quit mid experiment.

% Feel free to improve the instructions - use the existing code base as a
% reference point of how to do so. But you're welcome to just explain to
% participants what they need to do and I can add text when I get back from
% leave too.

VA5deg = calibrateMonitor();
adjustStim(VA5deg);
wheelTexture = DrawWheel();
orientationTexture = DrawOrientationWheel();
neutralTexture     = DrawNeutralWheel();

try
    % frontload the feedback creation texture
    DrawIntertrialFeedback(trials,1, false);
    blank(0);
    % Create the cue sin wave functions
    CueCreation(false); % flase = don't display them on screen
    
    instructions(1);
    % Practice Loop
    for ii = 1:size(practrials,1)
        if ii == 1 || ii == size(practrials,1)/2+1
            if practrials.CueOrder_i(ii) == 0
                instructions(2);
            else
                instructions(3);
            end
        end
        fixation(Visual.Durations.FixationDuration);
    
        PreCue(practrials(ii,:), wheelTexture, orientationTexture, neutralTexture);
        WaitSecs(Visual.Durations.PreCueDuration);
    
        DrawStimulus(practrials(ii,:));
        Screen('Flip', Visual.window);
        WaitSecs(Visual.Durations.StimulusDuration);

        Mask(practrials(ii,:));
        WaitSecs(Visual.Durations.MaskDuration);
        
        [practrials.MouseX{ii}, ...
             practrials.MouseY{ii}, ... 
             practrials.MouseAngles{ii}, ...
             practrials.MouseDistances{ii}, ...
             practrials.MouseTime{ii}, ...
             practrials.ResponseTime(ii), ... 
             practrials.ResponseAngle(ii), ...
             practrials.DerotatedResponseAngle(ii), ...
             practrials.Precision(ii)] = GetResponse(practrials(ii,:), wheelTexture, orientationTexture);
    
        [practrials.MouseInitTooSlow(ii), practrials.MouseInitTooFast(ii), practrials.TrialTooSlow(ii)] = speedCheck(practrials(ii,:));
        DrawWheelFeedback(practrials(ii,:), wheelTexture, orientationTexture);
        
        if practrials.TrialTooSlow(ii) || practrials.MouseInitTooSlow(ii) || practrials.MouseInitTooFast(ii)
            WaitSecs(Visual.Durations.FeedbackPenaltyDuration);
        else
            WaitSecs(Visual.Durations.FeedbackDuration);
        end
        DrawIntertrialFeedback(practrials,ii);

    end


    % Main Experimental Loop
    for ii = 1:size(trials,1)
        if ii == 1 || ii == size(trials,1)/2+1
            if trials.CueOrder_i(ii) == 0
                instructions(4);
            else
                instructions(5);
            end
        end
        fixation(Visual.Durations.FixationDuration);
    
        PreCue(trials(ii,:), wheelTexture, orientationTexture, neutralTexture);
        WaitSecs(Visual.Durations.PreCueDuration);
    
        DrawStimulus(trials(ii,:));
        Screen('Flip', Visual.window);
        WaitSecs(Visual.Durations.StimulusDuration);

        Mask(trials(ii,:));
        WaitSecs(Visual.Durations.MaskDuration);
        
        [trials.MouseX{ii}, ...
             trials.MouseY{ii}, ... 
             trials.MouseAngles{ii}, ...
             trials.MouseDistances{ii}, ...
             trials.MouseTime{ii}, ...
             trials.ResponseTime(ii), ... 
             trials.ResponseAngle(ii), ...
             trials.DerotatedResponseAngle(ii), ...
             trials.Precision(ii)] = GetResponse(trials(ii,:), wheelTexture, orientationTexture);
    
        [trials.MouseInitTooSlow(ii), trials.MouseInitTooFast(ii), trials.TrialTooSlow(ii)] = speedCheck(trials(ii,:));
        DrawWheelFeedback(trials(ii,:), wheelTexture, orientationTexture);
        
        if trials.TrialTooSlow(ii) || trials.MouseInitTooSlow(ii) || trials.MouseInitTooFast(ii)
            WaitSecs(Visual.Durations.FeedbackPenaltyDuration);
        else
            WaitSecs(Visual.Durations.FeedbackDuration);
        end

        DrawIntertrialFeedback(trials,ii);
        

    end
    SaveData(trials, sessionN, participantID, timestamp)
    ExperimentEnd(true);
catch ME 
    disp('An error occurred:');
    disp(ME.message);
    ExperimentEnd(false);
end

% Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [] = instructions(n)
    global Visual
    m = .25;
    if n == 1
        inst = ['Welcome to the Color-Orientation task.\n\n\n\n' ...
            'In this task, you will view 1, 2 or 4 colored triangles.\n\n\n\n' ...
            'Using your mouse, you will be cued to report either\n\n' ... 
            'the orientation or color of a triangle.'];
    elseif n == 2
        inst = ['This is the PreCue practice block. Before the stimulus, you will\n\n' ...
            'be cued to report either color (wavy border) or orientation (spiky border).\n\n'];
    elseif n == 3
        inst = ['This is the PostCue practice block. After the stimulus, you will\n\n' ...
            'be cued to report either color (wavy border) or orientation (spiky border).\n\n'];
    elseif n == 4
        inst = ['This is the PreCue experimental block. Before the stimulus, you will\n\n' ...
            'be cued to report either color (wavy border) or orientation (spiky border).\n\n'];
    elseif n == 5
        inst = ['This is the PostCue experimental block. After the stimulus, you will\n\n' ...
            'be cued to report either color (wavy border) or orientation (spiky border).\n\n'];
    end
    Screen('TextSize', Visual.window, 50);
    DrawFormattedText(Visual.window, inst, 'center', Visual.windowRect(4) * m, [255, 255, 255]);
    DrawFormattedText(Visual.window, 'Press The Left Mouse Button To Continue', 'center', Visual.windowRect(4) * .95, [255, 255, 255]);
    Screen('Flip', Visual.window);
    WaitForMouseClick();
end


function [] = WaitForMouseClick()
    global Visual
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
        
        if keyIsDown && keyCode(Visual.Keys.ctrlKey) && keyCode(Visual.Keys.quitKey)
            disp('Quit Buttons Pressed. Erroring Out Of The Experiment...');
            QuitButtonsPressed;
        end
        
        WaitSecs(0.016);  % check each frame, 16ms
    end
end


function [graphTexture, dstRect] = DrawIntertrialFeedback(trials, ii, display)
    global Visual
    if ~exist('display','var')
        display = true;
    end
    
    Precision    = round((180 - abs(trials.Precision)) / 180 * 100);
    ItemN        = trials.ItemN;
    uniqueItemNs = unique(ItemN);  % e.g. might be [1,2,4]
    trialJointCond = strcat(trials.CueOrder, '_', trials.CuedFeature);
    allJointConds = {'PreCue_Color', 'PreCue_Orientation', ...
                     'PostCue_Color','PostCue_Orientation'};

    colorBySetSize = [
        1.00, 0.45, 0.45;  % color if ItemN == 1
        0.45, 1.00, 0.45;  % color if ItemN == 2
        0.45, 0.45, 1.00   % color if ItemN == 4
    ];
    faceAlphaBySetSize = [1, 1, 1];

    clf;
    fig = figure('Visible', 'off', 'Color', 'w');
    
    % Manually define positions for each of the 4 subplots
    positions = [0.1, 0.6, 0.35, 0.3;  % top-left
                 0.55, 0.6, 0.35, 0.3; % top-right
                 0.1, 0.1, 0.35, 0.3;  % bottom-left
                 0.55, 0.1, 0.35, 0.3];% bottom-right

    for c = 1:4
        axes('Position', positions(c, :));

        % Select only those trials that match this condition
        thisCond = allJointConds{c};
        idxCond  = strcmp(trialJointCond, thisCond);

        % Extract precision + itemN just for these trials
        thesePrecision = Precision(idxCond);
        theseItemN     = ItemN(idxCond);

        % Plot a bar for each trial in that subset
        b = bar(1:length(thesePrecision), thesePrecision, ...
                'FaceColor', 'flat', ...
                'EdgeColor', 'flat');

        cData = zeros(length(thesePrecision), 3);
        for iBar = 1:length(thesePrecision)
            % Find which itemN we have
            nThis = theseItemN(iBar);

            % Find the index in the uniqueItemNs array
            % e.g., if uniqueItemNs = [1,2,4], then find where nThis belongs
            idxN = (uniqueItemNs == nThis);

            % If you trust that nThis is always in uniqueItemNs, idxN is a single "true"
            % Assign the row from colorBySetSize
            cData(iBar,:) = colorBySetSize(idxN,:);

            % If you want per-bar alpha:
            alphaVal = faceAlphaBySetSize(idxN);
            % The bar object as a whole can only have one FaceAlpha. 
            % So if you want each bar to differ, you must do a patch-based approach 
            % or separate bar calls. 
            % For a simple approach, set one alpha for all bars = the last one:
            b.FaceAlpha = alphaVal;  
        end
        b.CData = cData;

        %-----------------------------------------
        % Format axes
        %-----------------------------------------
        ylim([-1, 100]);
        xlim([-1, length(thesePrecision)+1]);
        set(gca, 'LineWidth', 1, ...
                 'FontWeight', 'bold', ...
                 'FontSize', 10, ...
                 'Box', 'off', ...
                 'TickLabelInterpreter', 'LaTeX');
        ylabel('\bf Points', ...
               'FontWeight','bold', 'FontSize',12, 'Interpreter','LaTeX');
        xlabel('\bf Trial',  ...
               'FontWeight','bold', 'FontSize',12, 'Interpreter','LaTeX');
        title(['\bf ',  strrep(thisCond, '_', ' ')], ...
              'FontWeight','bold', 'FontSize',12, 'Interpreter','LaTeX');
        yticks(0:25:100);

        % You can choose an appropriate spacing for xticks:
        % e.g. every 5 trials, etc.
        if length(thesePrecision) > 0
            xticks(1 : round(length(thesePrecision)/5) : length(thesePrecision));
        end
        
    end

    %-------------------------
    % 5) Capture figure -> image -> texture
    %-------------------------
    figureSizeX = 20;  
    figureSizeY = 15;  
    set(fig, 'PaperUnits','centimeters',...
             'PaperPosition',[0 0 figureSizeX figureSizeY], ...
             'PaperSize',[figureSizeX figureSizeY]);
    frame      = getframe(fig);
    graphImage = frame.cdata;
    close(fig);

    graphTexture = Screen('MakeTexture', Visual.window, graphImage);

    [s1, s2, ~] = size(graphImage);
    [screenXpixels, screenYpixels] = Screen('WindowSize', Visual.window);
    dstRect = CenterRectOnPointd([0 0 s2 s1]*1.25, screenXpixels/2, screenYpixels/2);

    Screen('FillRect', Visual.window, [Visual.patch.bg, Visual.patch.bg, Visual.patch.bg]);
    Screen('Flip', Visual.window);
    Screen('DrawTexture', Visual.window, graphTexture, [], dstRect);
    Screen('TextSize', Visual.window, 50);
    DrawFormattedText(Visual.window, ['Completed Trial ', num2str(trials.Index(ii)), ' of ', num2str(size(trials,1))], 'center', Visual.windowRect(4) * .08, [255, 255, 255]);
    DrawFormattedText(Visual.window, 'Press The Left Mouse Button To Continue', 'center', round(Visual.windowRect(4) * .95), [255, 255, 255]);
    if display
        Screen('Flip', Visual.window);
        WaitForMouseClick();
    end
    Screen('Close', graphTexture)
end



%function [] = SaveData(trials, practrials, sessionN, participantID, timestamp)
function [] = SaveData(trials, sessionN, participantID, timestamp)
    global Visual
    saveDir = 'ColorOrientationData';
    if ~isfolder(saveDir)
        mkdir(saveDir);
        disp(['Save Data Directory Created: ', saveDir]);
    end
    fname = ['ColorOrientationData_', participantID, '_', num2str(sessionN), '_', timestamp, '.mat'];
    %save(fullfile(saveDir, fname), 'trials', 'Visual', 'practrials');
    save(fullfile(saveDir, fname), 'trials', 'Visual');
    disp(['Data File: ', fname ' saved in directory ', saveDir]);
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

function drawLineMarker(centerX, centerY, angle, color)
    global Visual
    % Calculate the start and end points of the line based on the angle
    xStart = centerX - (Visual.feedback.ticklength / 2) * cos(angle);
    yStart = centerY - (Visual.feedback.ticklength / 2) * sin(angle);
    xEnd = centerX + (Visual.feedback.ticklength / 2) * cos(angle);
    yEnd = centerY + (Visual.feedback.ticklength / 2) * sin(angle);
    Screen('DrawLine', Visual.window, color, xStart, yStart, xEnd, yEnd, Visual.feedback.linewidth);
end

function [] = DrawWheelFeedback(trial, wheelTexture, orientationTexture)
    global Visual
    if trial.CuedFeature_i == 0 %color
        Screen('DrawTexture', Visual.window, wheelTexture, [], [], Visual.color.rotation);
        rspAngle = deg2rad(mod(trial.ResponseAngle + Visual.color.rotation, 360));
        targetAngle = deg2rad(mod(trial.Colors{1}(trial.Target) + Visual.color.rotation, 360));

        rspX =  Visual.centerX + Visual.annulus.radiusOuter * 1.1 * cos(rspAngle);
        rspY =  Visual.centerY + Visual.annulus.radiusOuter * 1.1 * sin(rspAngle);
        tarX =  Visual.centerX + Visual.annulus.radiusOuter * 1.1 * cos(targetAngle);
        tarY =  Visual.centerY + Visual.annulus.radiusOuter * 1.1 * sin(targetAngle);
        drawLineMarker(rspX, rspY, rspAngle, [255, 0, 0]);  % Red for response angle
        drawLineMarker(tarX, tarY, targetAngle, [0, 255, 0]);  % Green for target angle
    
    else % orientation
        Screen('DrawTexture', Visual.window, orientationTexture);
        rspAngle = deg2rad(mod(trial.ResponseAngle - 90, 360));
        targetAngle = deg2rad(mod(trial.Orientations{1}(trial.Target) - 90, 360));

        rspX =  Visual.centerX + Visual.annulus.radiusOuter * 1.1 * cos(rspAngle);
        rspY =  Visual.centerY + Visual.annulus.radiusOuter * 1.1 * sin(rspAngle);
        tarX =  Visual.centerX + Visual.annulus.radiusOuter * 1.1 * cos(targetAngle);
        tarY =  Visual.centerY + Visual.annulus.radiusOuter * 1.1 * sin(targetAngle);
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
        Screen('TextSize', Visual.window, 40);
        DrawFormattedText(Visual.window, feedback, 'center', Visual.windowRect(4)/2, [255, 0, 0]);
    end
    Screen('Flip', Visual.window);
end

function drawShortestArc(startAngle, endAngle)
    global Visual
    arcRadius = Visual.annulus.radiusOuter * 1.1;
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
        x1 = Visual.centerX + arcRadius * cos(currentAngle);
        y1 = Visual.centerY + arcRadius * sin(currentAngle);
        x2 = Visual.centerX + arcRadius * cos(nextAngle);
        y2 = Visual.centerY + arcRadius * sin(nextAngle);

        % Draw a line between the current point and the next point
        Screen('DrawLine', Visual.window, [0, 255, 0], x1, y1, x2, y2, Visual.feedback.linewidth);
    end
end

function [relativeX, relativeY, angle, distance] = TrackMouse()
    global Visual
    % Get the current mouse position
    [mouseX, mouseY] = GetMouse(Visual.window);
    
    % Calculate the relative position from the center of the screen
    relativeX = mouseX - Visual.centerX;
    relativeY = mouseY - Visual.centerY;
    
    % Calculate the angle (in degrees) relative to the center
    angle = atan2d(relativeY, relativeX);
    if angle < 0
        angle = angle + 360; % Ensure the angle is between 0 and 359.99 degrees
    end
    
    % Calculate the distance from the center
    distance = sqrt(relativeX^2 + relativeY^2);
end

function v = StimulusDurations()
    v.FixationDuration   = 0.2; % in seconds, this is how psychtoolbox works
    v.StimulusDuration   = 0.4;
    v.FeedbackDuration   = 0.5;
    v.FeedbackPenaltyDuration = v.FeedbackDuration * 4;
    v.PreCueDuration     = 1.0;
    v.PostCueDuration    = 0.5;
    v.MaskDuration       = 0.8;
    v.ResponseDuration   = 10;
    v.TrialTooSlow       = 3000; % in milliseconds like the RT
end

function TargetCue(trial, refresh)
    global Visual
    if ~exist('refresh', 'var')
        refresh = true;
    end
    for ii = 1:trial.ItemN
        theta = deg2rad(trial.StimulusLocations{1}(ii));
        centerX = Visual.centerX + Visual.stim.positionradius * cos(theta);
        centerY = Visual.centerY + Visual.stim.positionradius * sin(theta);
        basePedestal = [0, 0, Visual.stim.pedestalradius * 2, Visual.stim.pedestalradius * 2];
        centeredPedestal = CenterRectOnPoint(basePedestal, centerX, centerY);
        if (ii == trial.Target)
            if trial.CuedFeature_i == 0
                %Screen('FrameOval', Visual.window, Visual.cue.Oricolor, centeredPedestal, Visual.cue.borderwidth);
                waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    Visual.cue.Ravg, ...
                    Visual.cue.gentleAmp, ...
                    Visual.cue.gentleFreq);
                Screen('FillPoly', Visual.window, [255 255 255], waveCoords)
            elseif trial.CuedFeature_i == 1
                 %Screen('FrameOval', Visual.window, Visual.cue.Colcolor, centeredPedestal, Visual.cue.borderwidth);
                 waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    Visual.cue.Ravg, ...
                    Visual.cue.spikyAmp, ...
                    Visual.cue.spikyFreq);
                Screen('FillPoly', Visual.window, [255 255 255], waveCoords)
            end
        end
        Screen('FillOval', Visual.window, Visual.cue.Bgcolor, centeredPedestal);
    end
    fixation(0);
    if refresh
        Screen('Flip', Visual.window);
    end
end

function PreCue(trial, wheelTexture, orientationTexture, neutralTexture)
    global Visual
    if trial.CueOrder_i == 0
        if trial.CuedFeature_i == 0
            % Color
            Screen('DrawTexture', Visual.window, wheelTexture, [], [], Visual.color.rotation);
        elseif trial.CuedFeature_i == 1
            % Orient
            Screen('DrawTexture', Visual.window, orientationTexture);
        end
    else
        Screen('DrawTexture', Visual.window, neutralTexture);
    end

    fixation(0);
    Screen('Flip', Visual.window);
end

function noiseMaskTex = GaussianTexture()
    global Visual
    patchSize = round(Visual.stim.pedestalradius * 2);
    meanGray  = round(255/2);
    noiseAmp  = round(255/4);
    sigma     = round(patchSize * .25);
    noise2D = (rand(patchSize) * 2 - 1)*noiseAmp + meanGray;
    noise2D = max(0, min(noise2D, 255));
    [x, y] = meshgrid( ...
        linspace(-patchSize/2, +patchSize/2, patchSize), ...
        linspace(-patchSize/2, +patchSize/2, patchSize) );
    distFromCenter = sqrt(x.^2 + y.^2);
    circleMask = (distFromCenter <= Visual.stim.pedestalradius);
    gauss2D    = exp( -(distFromCenter.^2) / (2*sigma^2) );
    alpha2D = gauss2D .* circleMask;
    noiseImage = zeros(patchSize, patchSize, 4, 'uint8');
    noiseImage(:,:,1) = uint8(noise2D);                 % R
    noiseImage(:,:,2) = uint8(noise2D);                 % G
    noiseImage(:,:,3) = uint8(noise2D);                 % B
    noiseImage(:,:,4) = uint8(alpha2D * 255);           % alpha
    noiseMaskTex = Screen('MakeTexture', Visual.window, noiseImage);
end

function Mask(trial)
    global Visual
    for ii = 1:trial.ItemN
        noiseMaskTex = GaussianTexture;
        theta = deg2rad(trial.StimulusLocations{1}(ii));
        centerX = Visual.centerX + Visual.stim.positionradius * cos(theta);
        centerY = Visual.centerY + Visual.stim.positionradius * sin(theta);
        basePedestal = [0, 0, Visual.stim.pedestalradius * 2, Visual.stim.pedestalradius * 2];
        centeredPedestal = CenterRectOnPoint(basePedestal, centerX, centerY);
        Screen('FillOval', Visual.window, Visual.cue.Bgcolor, centeredPedestal);
        Screen('DrawTexture', Visual.window, noiseMaskTex, [], centeredPedestal);
        Screen('Close', noiseMaskTex);
    end
    fixation(0);
    Screen('Flip', Visual.window);
end

function [x, y, angles, distances, mousetime, rt, responseangle, derotatedAngle, precision] = GetResponse(trial, wheelTexture, orientationTexture)
    global Visual
    Screen('FillRect', Visual.window, [Visual.patch.bg, Visual.patch.bg, Visual.patch.bg]);
    if trial.CuedFeature_i == false
        Screen('DrawTexture', Visual.window, wheelTexture, [], [], Visual.color.rotation);
    else
        Screen('DrawTexture', Visual.window, orientationTexture);
    end
    fixation(0);
    %Cue(trial, true, false, false)
    TargetCue(trial, false);
    Screen('Flip', Visual.window);
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
    SetMouse(Visual.centerX, Visual.centerY, Visual.window);
    ShowCursor('Arrow');
    FlushEvents('keyDown'); 
    while Run
        checktime = GetSecs;
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(Visual.Keys.ctrlKey) && keyCode(Visual.Keys.quitKey)
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

        if distance > Visual.annulus.radiusInner 
            
            Run = false;
            rt = mousetime(end);

            if trial.CuedFeature_i == true
                responseangle = mod(angles(end) + 90, 360);
                derotatedAngle = angles(end);
                precision = trial.Orientations{1}(trial.Target) - responseangle;
                if precision < -180; precision = precision + 360; end
                if precision > 180; precision = precisiopositionradiusn - 360; end

            else
                responseangle = mod(angles(end) - Visual.color.rotation, 360);
                derotatedAngle = mod( responseangle - trial.WheelRotation, 360 );
                precision = trial.Colors{1}(trial.Target) - responseangle;
                if precision < -180; precision = precision + 360; end
                if precision > 180; precision = precision - 360; end
            end
            %fprintf('Finish Angle: %f', responseangle);
            
        end

        if (GetSecs() - starttime) > Visual.Durations.ResponseDuration
            rt = Visual.Durations.ResponseDuration * 1000;
            responseangle = nan;
            derotatedAngle = nan;
            precision = nan;
            Run = false;
        end 
    end
    HideCursor();
end
    

function DrawStimulus(trial)
    global Visual
    cMap = Visual.color.map(1:size(Visual.color.map, 1) / 360:size(Visual.color.map, 1), :);
    fixation(0);
    for ii = 1:trial.ItemN
        theta = deg2rad(trial.StimulusLocations{1}(ii));
        centerX = Visual.centerX + Visual.stim.positionradius * cos(theta);
        centerY = Visual.centerY + Visual.stim.positionradius * sin(theta);
        
        basePedestal = [0, 0, Visual.stim.pedestalradius * 2, Visual.stim.pedestalradius * 2];
        centeredPedestal = CenterRectOnPoint(basePedestal, centerX, centerY);
        Screen('FillOval', Visual.window, Visual.stim.pedestalcolor, centeredPedestal);

        baseRect = [0, 0, Visual.stim.base, Visual.stim.height];
        centeredRect = CenterRectOnPoint(baseRect, centerX, centerY);
        
        triTexture = Screen('OpenOffscreenWindow', Visual.window, Visual.stim.pedestalcolor, baseRect);
        color = cMap(trial.Colors{1}(ii),:);

        triangleCoords = [Visual.stim.base/2, 0; 0, Visual.stim.height; ... 
            Visual.stim.base, Visual.stim.height];
        Screen('FillPoly', triTexture, color, triangleCoords);
        Screen('DrawTexture', Visual.window, triTexture, [], centeredRect, trial.Orientations{1}(ii));
        Screen('Close', triTexture); 
    end
end


function trials = TrialMatrix(n, sessionN, participantID, age, timestamp)
    global Visual
    stim = [1, 2, 4];
    if mod(sessionN, 2) == 1
        Order = 'PreCueFirst';
        cnds = {'PreCue','Color';'PreCue','Orientation';'PostCue','Color';'PostCue','Orientation'};
    elseif mod(sessionN, 2) == 0
        Order = 'PostCueFirst';
        cnds = {'PostCue','Color';'PostCue','Orientation';'PreCue','Color';'PreCue','Orientation'};
    end
    if mod(n, length(stim) * size(cnds,1)) > 0
        n = n + length(stim) * size(cnds,1) - mod(n, length(stim) * size(cnds,1));
    end
    iterations = n / (length(stim) * size(cnds,1));
    x = repelem(cnds, iterations * length(stim), 1);

    trials = table((1:n)', 'VariableNames', {'Index'});
    trials{:,'ID'} = {participantID};
    trials{:,'Age'} = age;
    trials{:,'StartTime'} = {timestamp};
    trials{:,'SessionOrder'} = {Order};
    trials{:,'SessionOrder_i'} = strcmp(Order, 'PostCueFirst');
    trials{:,'CueOrder'} = x(:,1);
    trials{:,'CueOrder_i'} = strcmp( x(:,1), 'PostCue');
    trials{:,'CuedFeature'} = x(:,2);
    trials{:,'CuedFeature_i'} = strcmp( x(:,2), 'Orientation');
    trials{:,'ItemN'} = repmat(stim,1, n/length(stim))';
    trials{:,'WheelRotation'} = Visual.color.rotation;
    
    trials{:,'Orientations'} = {nan};
    trials{:,'Colors'} = {nan};
    trials{:,'StimulusLocations'} = {nan};
    trials{:,'Target'} = 0;

    for ii = 1:n
        trials{ii,'Orientations'} = {randOrientations(trials.ItemN(ii))};
        trials{ii,'Colors'} = {randColors(trials.ItemN(ii))};
        trials{ii,'StimulusLocations'} = {(0:trials.ItemN(ii)-1) * (360 / trials.ItemN(ii)) + randi([0, (360 / trials.ItemN(ii)) - 1])};
        trials{ii,'Target'} = randi([1,trials.ItemN(ii)]);
    end

    % Collection Cells
    trials{:,'MouseX'} = {nan};
    trials{:,'MouseY'} = {nan};
    trials{:,'MouseAngles'} = {nan};
    trials{:,'MouseDistances'} = {nan};
    trials{:,'MouseTime'} = {nan};
    trials{:,'ResponseAngle'} = nan;
    trials{:,'DerotatedResponseAngle'} = nan;
    trials{:,'Precision'} = nan;
    trials{:,'ResponseTime'} = nan;
    trials{:,'MouseInitTooSlow'} = nan;
    trials{:,'MouseInitTooFast'} = nan;
    trials{:,'TrialTooSlow'} = nan;
    
    rndorder{1} = trials(trials.CueOrder_i == trials.CueOrder_i(1),:);
    rndorder{1} = rndorder{1}(randperm(size(rndorder{1},1)),:);
    rndorder{2} = trials(trials.CueOrder_i == trials.CueOrder_i(end),:);
    rndorder{2} = rndorder{2}(randperm(size(rndorder{2},1)),:);
    trials = [rndorder{1}; rndorder{2}];
    trials.Index = (1:size(trials,1))';
    

end

function [MouseTooSlow, MouseTooFast, TrialTooSlow] = speedCheck(trial)
    global Visual
    MouseTooSlow = false; 
    MouseTooFast = false; 
    TrialTooSlow = false;
    LeaveCenterRT = trial.MouseTime{1}(find(trial.MouseDistances{1} >= Visual.mouseinit.radius, 1));

    if LeaveCenterRT > Visual.mouseinit.tooslow
        MouseTooSlow = true;
    end
    if LeaveCenterRT < Visual.mouseinit.toofast
        MouseTooFast = true;
    end
    if trial.ResponseTime > Visual.Durations.TrialTooSlow
        TrialTooSlow = true;
    end
end

function d = minCircularDistance(angle, angles)
    diff = abs(angle - angles);
    d = min(diff, 360 - diff);
end

function x = randOrientations(n)
    minDist = 15;
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

function x = randColors(n)
    minDist = 30;
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

function fiveDegVA_in_pixels = calibrateMonitor()
    global Visual

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

        DrawFormattedText(Visual.window, ...
            'Align these two lines with the edges of your credit card.\n\nUse LEFT/RIGHT arrow keys to move each line.\nUse UP/DOWN arrow keys to choose which line moves.\nPress ENTER when done.', ...
            'center', 'center', [255 255 255]);
        Screen('Flip', Visual.window);
        WaitSecs(1);
        blank(0);
    
        leftLineX = Visual.centerX - Visual.centerX * .33;
        rightLineX = Visual.centerX + Visual.centerX * .33;
        currentLine = 'left';
    
        done = false;
        moveStep = 1; % 1 pixel for precision
        while ~done
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown
                if keyIsDown && keyCode(Visual.Keys.ctrlKey) && keyCode(Visual.Keys.quitKey)
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
                elseif keyCode(KbName('Return'))
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
    
            Screen('DrawLine', Visual.window, lineIndicatorLeft, ...
                leftLineX, 0, leftLineX, Visual.windowRect(4), 2);
            Screen('DrawLine', Visual.window, lineIndicatorRight, ...
                rightLineX, 0, rightLineX, Visual.windowRect(4), 2);
            DrawFormattedText(Visual.window, ...
                'Use arrow keys to move lines. Press ENTER when done.', ...
                'center', 50, [255 255 255]);
            Screen('Flip', Visual.window);
            WaitSecs(0.01);
    
        end
        blank(0);
        measured = rightLineX - leftLineX;
        CreditCardWith = 85.60;
        pixelsPerMm = measured / CreditCardWith;
        viewingdistance = 900; % 60cm
        desiredAngleDeg = 5; % 5 degree visual angle
        stim_in_mm = 2 * viewingdistance * tan((desiredAngleDeg / 2) * (pi/180));
        fiveDegVA_in_pixels = round( stim_in_mm * pixelsPerMm );

        savedConfig = currentConfig; 
        calibrationData = fiveDegVA_in_pixels; 
        save('screenCalibration.mat', 'savedConfig', 'calibrationData');
    end

end

function v = initiate()
    v.patch.bg = .5 * 255;
    Screen('Preference', 'SkipSyncTests', 1); % Skip synchronization tests (not recommended for actual experiments)
    Screen('Preference', 'VisualDebugLevel', 0); % Minimal feedback
    [v.window, v.windowRect] = Screen('OpenWindow', max(Screen('Screens')), [v.patch.bg, v.patch.bg, v.patch.bg]); % Open a grey window on the main screen
    Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Flip', v.window); % Flip to the window to update it
    [v.centerX, v.centerY] = RectCenter(v.windowRect);
    Screen('TextSize', v.window, 24);
    disp('Psychtoolbox initialized successfully');

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
    v.color.rotation = randi([0, 359]);
    
    v.Keys = ResponseKeys();
    v.Durations = StimulusDurations();

end

function [] = adjustStim(VA5deg)
    global Visual
    fiveDegCirc = [Visual.centerX - VA5deg/2, Visual.centerY - VA5deg/2, Visual.centerX + VA5deg/2, Visual.centerY + VA5deg/2];
    Screen('FillOval', Visual.window, [255 255 255], fiveDegCirc);
    DrawFormattedText(Visual.window, ...
        '5 Degrees VA Calibrated @ 60cm\nRecalibrate if incorrect.', ...
        'center', 'center', [0, 0, 0]);
    Screen('Flip', Visual.window);
    WaitSecs(.2);
    deg = VA5deg / 5;

    Visual.annulus.radiusOuter = round(deg * 4.75);
    Visual.annulus.radiusInner = round(deg * 4.25);

    Visual.stim.positionradius = round(deg * 1.5);
    Visual.stim.triAngles = [36, 72, 72];
    Visual.stim.base = round(deg * .75);
    Visual.stim.height = round(Visual.stim.base / (2 * tand(Visual.stim.triAngles(1)/2)));
    Visual.stim.triArea = Visual.stim.height * Visual.stim.base * .5;
    Visual.stim.pedestalradius = Visual.stim.base * 1.25; 
    Visual.stim.pedestalcolor = [0, 0, 0];

    Visual.mouseinit.radius = round(deg * .4);
    Visual.mouseinit.radiusWidth = round(deg * .03);
    Visual.mouseinit.color = [85, 85, 85];
    % Note this is the mouse timing 
    Visual.mouseinit.toofast = 100;
    Visual.mouseinit.tooslow = 1500;
    
    Visual.feedback.linewidth = round(deg * .06);
    Visual.feedback.ticklength = round(deg * .4);

    % Changed color cues to sin wave cues.
    %Visual.cue.borderwidth = round(deg * .1);
    %Visual.cue.Colcolor = [0, 0, 255];
    %Visual.cue.Oricolor = [0, 255, 0];
    %Visual.cue.Neutcolor = [255, 255, 255] * .75;
    Visual.cue.Bgcolor = [0, 0, 0];
    Visual.cue.PedestalMultiplier = 1.05;
    Visual.cue.radius = Visual.stim.pedestalradius * Visual.cue.PedestalMultiplier;
    Visual.cue.ringArea = pi * (Visual.cue.radius^2 - Visual.stim.pedestalradius^2);
    Visual.cue.gentleFreq = 8;
    Visual.cue.spikyFreq  = 36;
    Visual.cue.Ravg = (Visual.stim.pedestalradius + Visual.cue.radius)/2; % imaginary midpoint of the osilations
    % Integral calculations for gentle and spiky waves.
    %   Compute once at start of code to calc the correct values
    %   and then use throughout the experiment.
    Visual.cue.gentleAmp = SolveWaveAmplitude(Visual.cue.ringArea, Visual.stim.pedestalradius, Visual.cue.Ravg, Visual.cue.gentleFreq);
    Visual.cue.spikyAmp  = SolveWaveAmplitude(Visual.cue.ringArea, Visual.stim.pedestalradius, Visual.cue.Ravg, Visual.cue.spikyFreq);


end

function [] = blank(duration)
    global Visual
    Screen('FillRect', Visual.window, [Visual.patch.bg, Visual.patch.bg, Visual.patch.bg]);
    Screen('Flip', Visual.window);
    if duration > 0
        WaitSecs(duration);
    end
end

function v = ResponseKeys()
    v.ctrlKey = KbName('LeftControl');  
    v.quitKey = KbName('l');
end

function [] = ExperimentEnd(Finished)
    global Visual
    allTextures = Screen('WindowKind');
    for i = 1:length(allTextures)
       Screen('Close', allTextures(i));
    end
    close all;
    if Finished
        Screen('TextSize', Visual.window, 50);
        DrawFormattedText(Visual.window, 'Experiment Complete!\n\nThank you for your participation.', 'center', Visual.windowRect(4)/2, [255, 255, 255]);
        Screen('Flip', Visual.window);
        WaitSecs(4);
    else
        Screen('TextSize', Visual.window, 50);
        DrawFormattedText(Visual.window, 'Terminating Experiment.', 'center', Visual.windowRect(4)/2, [255, 255, 255]);
        Screen('Flip', Visual.window);
        WaitSecs(1);
    end
    sca; %Screen('CloseAll');
    disp('Experiment Code Finished');
end

function [] = fixation(duration)
    global Visual
    fixCrossDimPix = 10;
    xCoords = [-fixCrossDimPix, fixCrossDimPix, 0, 0];
    yCoords = [0, 0, -fixCrossDimPix, fixCrossDimPix];
    allCoords = [xCoords; yCoords];
    lineWidthPix = 2;
    Screen('DrawLines', Visual.window, allCoords, lineWidthPix, repmat(255*.25,1,3), [Visual.centerX, Visual.centerY]);
    circleRadius = fixCrossDimPix; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, Visual.centerX, Visual.centerY);
    Screen('FrameOval', Visual.window, repmat(255*.25,1,3), circleRect, lineWidthPix);
    circleRadius = 2; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, Visual.centerX, Visual.centerY);
    Screen('FrameOval', Visual.window, repmat(255*.75,1,3), circleRect, lineWidthPix);
    if duration > 0
        Screen('Flip', Visual.window);
        WaitSecs(duration);
    end
end

function texture = DrawWheel()
    global Visual
    offScreenWindow = Screen('OpenOffscreenWindow', Visual.window, Visual.patch.bg, Visual.windowRect);
    % Draw the color wheel onto the screen
    for ii = 1:length(Visual.color.angles)
        % Calculate the endpoint of each line in the annulus
        xStart = Visual.centerX + Visual.annulus.radiusInner * cos(Visual.color.angles(ii));
        yStart = Visual.centerY + Visual.annulus.radiusInner * sin(Visual.color.angles(ii));
        xEnd = Visual.centerX + Visual.annulus.radiusOuter * cos(Visual.color.angles(ii));
        yEnd = Visual.centerY + Visual.annulus.radiusOuter * sin(Visual.color.angles(ii));
        Screen('DrawLine', offScreenWindow, Visual.color.map(ii, :), xStart, yStart, xEnd, yEnd, 2);
    end
    
    rect = [Visual.centerX - Visual.mouseinit.radius, Visual.centerY - Visual.mouseinit.radius, ...
            Visual.centerX + Visual.mouseinit.radius, Visual.centerY + Visual.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, Visual.mouseinit.color, rect, Visual.mouseinit.radiusWidth);
    
    % Save the current screen content as a texture
    texture = Screen('MakeTexture', Visual.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
end

function texture = DrawNeutralWheel()
    global Visual
    offScreenWindow = Screen('OpenOffscreenWindow', Visual.window, Visual.patch.bg, Visual.windowRect);
    Screen('FrameOval', offScreenWindow, [255, 255, 255], ...
           [Visual.centerX - Visual.annulus.radiusOuter, Visual.centerY - Visual.annulus.radiusOuter, ...
            Visual.centerX + Visual.annulus.radiusOuter, Visual.centerY + Visual.annulus.radiusOuter], ...
           Visual.annulus.radiusOuter - Visual.annulus.radiusInner);
    % Add the mouse initiate ring
    rect = [Visual.centerX - Visual.mouseinit.radius, Visual.centerY - Visual.mouseinit.radius, ...
            Visual.centerX + Visual.mouseinit.radius, Visual.centerY + Visual.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, Visual.mouseinit.color, rect, Visual.mouseinit.radiusWidth);
    % Create a texture from the offscreen window content
    texture = Screen('MakeTexture', Visual.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
end

function texture = DrawOrientationWheel()
    global Visual
    offScreenWindow = Screen('OpenOffscreenWindow', Visual.window, Visual.patch.bg, Visual.windowRect);
    Screen('FrameOval', offScreenWindow, [255, 255, 255], ...
           [Visual.centerX - Visual.annulus.radiusOuter, Visual.centerY - Visual.annulus.radiusOuter, ...
            Visual.centerX + Visual.annulus.radiusOuter, Visual.centerY + Visual.annulus.radiusOuter], ...
           Visual.annulus.radiusOuter - Visual.annulus.radiusInner);
    lineLength = Visual.annulus.radiusOuter - Visual.annulus.radiusInner;
    % Top and bottom lines
    Screen('DrawLine', offScreenWindow, [255, 255, 255], ...
           Visual.centerX, Visual.centerY - Visual.annulus.radiusOuter, ...
           Visual.centerX, Visual.centerY - Visual.annulus.radiusOuter - lineLength, 3);
    Screen('DrawLine', offScreenWindow, [255, 255, 255], ...
           Visual.centerX, Visual.centerY + Visual.annulus.radiusOuter, ...
           Visual.centerX, Visual.centerY + Visual.annulus.radiusOuter + lineLength, 3);

    % Left and right lines
    Screen('DrawLine', offScreenWindow, [255, 255, 255], ...
           Visual.centerX - Visual.annulus.radiusOuter, Visual.centerY, ...
           Visual.centerX - Visual.annulus.radiusOuter - lineLength, Visual.centerY, 3);
    Screen('DrawLine', offScreenWindow, [255, 255, 255], ...
           Visual.centerX + Visual.annulus.radiusOuter, Visual.centerY, ...
           Visual.centerX + Visual.annulus.radiusOuter + lineLength, Visual.centerY, 3);
    % Add the mouse initiate ring
    rect = [Visual.centerX - Visual.mouseinit.radius, Visual.centerY - Visual.mouseinit.radius, ...
            Visual.centerX + Visual.mouseinit.radius, Visual.centerY + Visual.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, Visual.mouseinit.color, rect, Visual.mouseinit.radiusWidth);
    % Create a texture from the offscreen window content
    texture = Screen('MakeTexture', Visual.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
end

function CueCreation(display)
    global Visual
    theta = deg2rad(1);
    centerX = Visual.centerX + Visual.stim.positionradius * cos(theta);
    centerY = Visual.centerY + Visual.stim.positionradius * sin(theta);
    basePedestal = [0, 0, Visual.stim.pedestalradius * 2, Visual.stim.pedestalradius * 2];
    centeredPedestal = CenterRectOnPoint(basePedestal, centerX, centerY);

    if display
        for cues = 1:3
    
            if cues == 2
                % Add gentle wave
                %Screen('FrameOval', Visual.window, Visual.cue.Oricolor, centeredPedestal, Visual.cue.borderwidth);
                waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    Visual.cue.Ravg, ...
                    Visual.cue.gentleAmp, ...
                    Visual.cue.gentleFreq);
                Screen('FillPoly', Visual.window, [255 255 255], waveCoords)
        
            elseif cues == 3
                % Add spiky wave
                %Screen('FrameOval', Visual.window, Visual.cue.Colcolor, centeredPedestal, Visual.cue.borderwidth);
                waveCoords = BuildWaveCoords( ...
                    centerX, centerY, ...
                    Visual.cue.Ravg, ...
                    Visual.cue.spikyAmp, ...
                    Visual.cue.spikyFreq);
                Screen('FillPoly', Visual.window, [255 255 255], waveCoords)
            elseif cues == 1
                % Add smooth boarder, of equal area to waves.
                %Screen('FrameOval', Visual.window, Visual.cue.Neutcolor, centeredPedestal, Visual.cue.borderwidth);
                cueSurface = [0, 0, Visual.cue.radius * 2, Visual.cue.radius * 2];
                centeredCue = CenterRectOnPoint(cueSurface, centerX, centerY);
                Screen('FillOval', Visual.window, [255 255 255], centeredCue);
            end
    
            % Add black pedestal overlay
            Screen('FillOval', Visual.window, Visual.cue.Bgcolor, centeredPedestal);
            
            fixation(0);
            Screen('Flip', Visual.window);
            WaitSecs(1);
        end
    end
end

function Afound = SolveWaveAmplitude(ringArea, Rinner, Ravg, freq)
    A0 = 50; % initial guess in pixels
    options = optimset('TolX',1e-3, 'Display','off');
    Afound = fminsearch(@(A) areaDiff(A, ringArea, Rinner, Ravg, freq), A0, options);
end

% The objective function to minimize (difference from desired area):
function diffVal = areaDiff(A, ringArea, Rinner, Ravg, freq)
    % Evaluate the wave area
    waveArea = WaveRingArea(A, Rinner, Ravg, freq);
    diffVal  = abs(waveArea - ringArea);
end

function areaVal = WaveRingArea(A, Rinner, Ravg, freq)
    nSteps = 2000; 
    thetaVals = linspace(0, 2*pi, nSteps);
    Rvals = (Ravg + A*sin(freq * thetaVals)); 
    RvalsSquared = Rvals.^2;

    inside = 0.5 * (RvalsSquared - Rinner^2);
    % Make sure negative inside doesn't happen if amplitude is large:
    inside(inside < 0) = 0; 

    % Numeric integration
    areaVal = trapz(thetaVals, inside);
end

function XY = BuildWaveCoords(centerX, centerY, Ravg, A, freq)
    % Build a polygon for R(θ) = Ravg + A*sin(freq*θ)
    % from θ=0..2π, excluding the region inside Rinner
    % We'll just build the OUTER boundary.

    nSteps = 200;
    thetaVals = linspace(0, 2*pi, nSteps);
    Rvals = Ravg + A*sin(freq * thetaVals);

    xvals = centerX + Rvals .* cos(thetaVals);
    yvals = centerY + Rvals .* sin(thetaVals);
    XY = [xvals(:), yvals(:)];
end
