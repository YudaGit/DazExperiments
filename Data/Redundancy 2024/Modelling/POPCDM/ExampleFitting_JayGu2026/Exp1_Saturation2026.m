clear; close all; clc;
format shortg
KbName('UnifyKeyNames');

% ID FORMAT
% IDs must be in the format letter,number,number.
%    For example, P01, P02, P03, ... P10, P11 ...
% ID number and Session Number combine to create a counter balanced
%    saturation x session x participant design structure.

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
participantID = input('Enter Participant ID: ', 's');
sessionN = str2double(input('Enter Session Number (1 - 10): ', 's'));
age = str2double(input('Enter Age Number (17 - 99): ', 's'));
gender = str2double(input('Enter Gender (0 = M, 1 = W, 2 = O): ', 's'));

global Visual
n = 360;

if isnan(gender) || isnan(age) || isnan(sessionN) || ...
        isempty(participantID) || (gender > 2 || gender < 0) || ...
        (age < 17 || age > 99) || (sessionN < 0 || sessionN > 10) || ...
        length(participantID) ~= 3 || isempty(str2num(participantID(2:end))) 
    fprintf('\nERROR: Enter correct participant details.\n\n')
    ExperimentEnd(false);
end


Visual = initiate();
VA5deg = calibrateMonitor();
adjustStim(VA5deg);

[Visual.color.high, Visual.color.angles] = LUVcolors_safe(Visual.color.centerLUV, Visual.color.high_radiusLUV, 1);
Visual.color.low       = LUVcolors_safe(Visual.color.centerLUV, Visual.color.low_radiusLUV,  1);
Visual.color.HighWheel = DrawWheel(1);

try 
    instructions(1);
    instructions(2);
    % Practice Trials
    practrials = TrialMatrix(4, sessionN, participantID, age, timestamp);
    for trial = 1:size(practrials,1)

        blank(0);
        fixation(Visual.Durations.FixationDuration);

        DrawStimulus(practrials(trial,:));
        Screen('Flip', Visual.window);
        WaitSecs(Visual.Durations.StimulusDuration * 2);

        fixation(0);
        Screen('Flip', Visual.window);
        WaitSecs(Visual.Durations.RetentionDuration);

        [practrials.MouseX{trial}, ...
             practrials.MouseY{trial}, ... 
             practrials.MouseAngles{trial}, ...
             practrials.MouseDistances{trial}, ...
             practrials.MouseTime{trial}, ...
             practrials.ResponseTime(trial), ... 
             practrials.ResponseAngle(trial), ...
             practrials.DerotatedResponseAngle(trial), ...
             practrials.Precision(trial), ...
             practrials.MouseInitTooSlow(trial), ...
             practrials.MouseInitTooFast(trial), ...
             practrials.TrialTooSlow(trial) ] = GetResponse(practrials(trial,:));

        DrawIntertrialFeedback(practrials, trial);
    end
    
    instructions(3);

    % Experimental Trials 
    trials = TrialMatrix(n, sessionN, participantID, age, timestamp);
    
    for trial = 1:size(trials,1)

        blank(0);
        fixation(Visual.Durations.FixationDuration);

        DrawStimulus(trials(trial,:));
        Screen('Flip', Visual.window);
        WaitSecs(Visual.Durations.StimulusDuration);

        fixation(0);
        Screen('Flip', Visual.window);
        WaitSecs(Visual.Durations.RetentionDuration);

        [trials.MouseX{trial}, ...
             trials.MouseY{trial}, ... 
             trials.MouseAngles{trial}, ...
             trials.MouseDistances{trial}, ...
             trials.MouseTime{trial}, ...
             trials.ResponseTime(trial), ... 
             trials.ResponseAngle(trial), ...
             trials.DerotatedResponseAngle(trial), ...
             trials.Precision(trial), ...
             trials.MouseInitTooSlow(trial), ...
             trials.MouseInitTooFast(trial), ...
             trials.TrialTooSlow(trial) ] = GetResponse(trials(trial,:));

        DrawIntertrialFeedback(trials, trial);
    end

    SaveData(trials, sessionN, participantID, timestamp);

    ExperimentEnd(true);
catch ME 
    disp('An error occurred:');
    disp(ME.message);
    ExperimentEnd(false);
end

function [] = instructions(n)
    global Visual
    m = .25;
    if n == 1
        inst = ['Welcome to the Color Recall task.\n\n\n\n' ...
            'In this task, you will view 1, 2, 4 or 6 colored items.\n\n\n\n' ...
            'Using your mouse, you will be asked to reproduce\n\n' ... 
            'the color of one item on a color wheel.'];
    elseif n == 2
        inst = ['This is a practice block. Colored items will remain\n\n' ...
                'on screen two-times longer than in the actual experiment.\n\n'];
    elseif n == 3
        inst = ['This is the start of the experimental trials.\n\n' ...
            'You can take a break between trials at any time.\n\n'];
    end
    Screen('TextSize', Visual.window, 50);
    DrawFormattedText(Visual.window, inst, 'center', Visual.windowRect(4) * m, [255, 255, 255]);
    DrawFormattedText(Visual.window, 'Press The Left Mouse Button To Continue', 'center', Visual.windowRect(4) * .95, [255, 255, 255]);
    Screen('Flip', Visual.window);
    WaitForMouseClick();
end

function [] = SaveData(trials, sessionN, participantID, timestamp)
    global Visual
    saveDir = 'Data_SaturationExp1';
    if ~isfolder(saveDir)
        mkdir(saveDir);
        disp(['Save Data Directory Created: ', saveDir]);
    end
    fname = ['SaturationExp1_', participantID, '_', num2str(sessionN), '_', timestamp, '.mat'];
    save(fullfile(saveDir, fname), 'trials', 'Visual');
    disp(['Data File: ', fname ' saved in directory ', saveDir]);
end


function [graphTexture, dstRect] = DrawIntertrialFeedback(trials, ii, display)
    global Visual
    if ~exist('display','var')
        display = true;
    end
    
    Precision    = round((180 - abs(trials.Precision)) / 180 * 100);
    ItemN        = trials.ItemN;
    uniqueItemNs = unique(ItemN);
    nConds       = numel(uniqueItemNs);

    colorBySetSize = [
        1.00, 0.45, 0.45;
        0.45, 1.00, 0.45;
        0.45, 0.45, 1.00;
        0.70, 0.00, 0.70
    ];

    fig = figure('Visible', 'off', 'Color', 'w');
    clf;

    nCols = ceil(sqrt(nConds));
    nRows = ceil(nConds / nCols);

    for c = 1:nConds
        subplot(nRows, nCols, c);

        thisItemN = uniqueItemNs(c);
        idxCond   = (ItemN == thisItemN);

        thesePrecision = Precision(idxCond);

        b = bar(1:length(thesePrecision), thesePrecision, ...
                'FaceColor', 'flat', ...
                'EdgeColor', 'flat');

        colorIdx = min(c, size(colorBySetSize,1));
        b.CData = repmat(colorBySetSize(colorIdx,:), length(thesePrecision), 1);
        b.FaceAlpha = 1;

        ylim([-1, 100]);
        xlim([0, max(1, length(thesePrecision)+1)]);
        set(gca, 'LineWidth', 1, ...
                 'FontWeight', 'bold', ...
                 'FontSize', 10, ...
                 'Box', 'off', ...
                 'TickLabelInterpreter', 'LaTeX');

        ylabel('\bf Points', ...
               'FontWeight','bold', 'FontSize',12, 'Interpreter','LaTeX');
        xlabel('\bf Trial', ...
               'FontWeight','bold', 'FontSize',12, 'Interpreter','LaTeX');
        title(sprintf('\\bf Set Size %d', thisItemN), ...
              'FontWeight','bold', 'FontSize',12, 'Interpreter','LaTeX');
        yticks(0:25:100);

        if ~isempty(thesePrecision)
            tickStep = max(1, round(length(thesePrecision)/5));
            xticks(1:tickStep:length(thesePrecision));
        end
    end

    figureSizeX = 20;
    figureSizeY = 15;
    set(fig, 'PaperUnits','centimeters', ...
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
    DrawFormattedText(Visual.window, ...
        ['Completed Trial ', num2str(trials.Index(ii)), ' of ', num2str(size(trials,1))], ...
        'center', Visual.windowRect(4) * .08, [255, 255, 255]);
    DrawFormattedText(Visual.window, ...
        'Press The Left Mouse Button To Continue', ...
        'center', round(Visual.windowRect(4) * .95), [255, 255, 255]);

    if display
        Screen('Flip', Visual.window);
        WaitForMouseClick();
    end

    Screen('Close', graphTexture)
end


function [x, y, angles, distances, mousetime, rt, responseangle, derotatedAngle, precision, MouseTooSlow, MouseTooFast, TrialTooSlow] = GetResponse(trial)
    global Visual
    Screen('FillRect', Visual.window, [Visual.patch.bg, Visual.patch.bg, Visual.patch.bg]);
    Screen('DrawTexture', Visual.window, Visual.color.HighWheel, [], [], Visual.color.rotation);
    fixation(0);
    CueItems(trial)
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
    FeedbackOn = true;

    MouseTooSlow = false; 
    MouseTooFast = false; 
    TrialTooSlow = false;
    FeedbackText = '';

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
            responseangle = mod(angles(end) - Visual.color.rotation, 360);
            derotatedAngle = mod( responseangle - trial.WheelRotation, 360 );
            precision = trial.StimulusColorAngles{1}(trial.TargetIndex) - responseangle;
            if precision < -180; precision = precision + 360; end
            if precision > 180; precision = precision - 360; end
        end

        if (GetSecs() - starttime) > Visual.Durations.ResponseDuration
            rt = Visual.Durations.ResponseDuration * 1000;
            responseangle = nan;
            derotatedAngle = nan;
            precision = nan;
            Run = false;
            FeedbackOn = false;
        end 

    end
    HideCursor();
    
    if FeedbackOn == false
        FeedbackText = 'Trial Timed Out';
        FeedbackTime = Visual.Durations.FeedbackPenalty;
    end

    if FeedbackOn
        
        rspAngle = deg2rad(mod(angles(end), 360));
        targetAngle = deg2rad(mod(trial.StimulusColorAngles{1}(trial.TargetIndex) + Visual.color.rotation, 360));
        rspX =  Visual.centerX + Visual.annulus.radiusOuter * 1.1 * cos(rspAngle);
        rspY =  Visual.centerY + Visual.annulus.radiusOuter * 1.1 * sin(rspAngle);
        tarX =  Visual.centerX + Visual.annulus.radiusOuter * 1.1 * cos(targetAngle);
        tarY =  Visual.centerY + Visual.annulus.radiusOuter * 1.1 * sin(targetAngle);
        
        Screen('FillRect', Visual.window, [Visual.patch.bg, Visual.patch.bg, Visual.patch.bg]);
        Screen('DrawTexture', Visual.window, Visual.color.HighWheel, [], [], Visual.color.rotation);
        fixation(0);
        CueItems(trial)
        
        drawLineMarker(rspX, rspY, rspAngle, [255, 0, 0]);  % Red for response angle
        drawLineMarker(tarX, tarY, targetAngle, [0, 255, 0]);  % Green for target angle
        drawShortestArc(rspAngle, targetAngle);
        
        FeedbackTime = Visual.Durations.FeedbackDuration;
        
        % Check response issues
        LeaveCenterRT = mousetime(find(distances >= Visual.mouseinit.radius, 1));

        if LeaveCenterRT > Visual.mouseinit.tooslow
            MouseTooSlow = true;
            FeedbackTime = Visual.Durations.FeedbackPenalty;
            FeedbackText = 'Initial Mouse Movement Too Slow';
        end
        if LeaveCenterRT < Visual.mouseinit.toofast
            MouseTooFast = true;
            FeedbackTime = Visual.Durations.FeedbackPenalty;
            FeedbackText = 'Initial Mouse Movement Too Fast';
        end
        if trial.ResponseTime > Visual.Durations.TrialTooSlow
            TrialTooSlow = true;
            FeedbackTime = Visual.Durations.FeedbackPenalty;
            FeedbackText = 'Response Was Too Slow';
        end


    end

    if ~strcmp(FeedbackText, '')
        Screen('TextSize', Visual.window, 40);
        DrawFormattedText(Visual.window, FeedbackText, 'center', Visual.windowRect(4)/2, [255, 0, 0]);
    end

    Screen('Flip', Visual.window);
    WaitSecs(FeedbackTime);
end

function CueItems(trial)
    global Visual
    for ii = 1:trial.ItemN
        theta    = deg2rad(trial.StimulusItemLocations{1}(ii));
        centerX  = Visual.centerX + Visual.stim.positionradius * cos(theta);
        centerY  = Visual.centerY + Visual.stim.positionradius * sin(theta);
        baseRect = [0 0  2*Visual.stim.radius  2*Visual.stim.radius];
        centeredRect = CenterRectOnPoint(baseRect, centerX, centerY);
        Screen('FillOval', Visual.window, [127.5, 127.5, 127.5], centeredRect);
        if (ii == trial.TargetIndex)
            Screen('FrameOval', Visual.window, [255 255 255], centeredRect, Visual.stim.targetcuewidth);
        else
            
        end
    end
end

function DrawStimulus(trial)
    global Visual
    fixation(0);
    for ii = 1:trial.ItemN
        theta = deg2rad(trial.StimulusItemLocations{1}(ii));
        centerX = Visual.centerX + Visual.stim.positionradius * cos(theta);
        centerY = Visual.centerY + Visual.stim.positionradius * sin(theta);

        
        if strcmp(trial.StimulusSaturation, 'high')
            color = Visual.color.high(trial.StimulusColorAngles{1}(ii), :);
        else
            color = Visual.color.low(trial.StimulusColorAngles{1}(ii), :);
        end

        color = color * 255;
        radius      = Visual.stim.radius;
        baseRect    = [0 0  2*radius  2*radius];
        centeredRect = CenterRectOnPoint(baseRect, centerX, centerY);
        
        stimTexture = Screen('OpenOffscreenWindow', Visual.window, [0,0,0], baseRect);
        Screen('FillOval', stimTexture, color, baseRect);
        Screen('DrawTexture', Visual.window, stimTexture, [], centeredRect, 0);
        Screen('Close', stimTexture); 
    end

end

function texture = DrawWheel(saturation)
    global Visual
    scale = 10;
    if saturation == 1
        [colormap, angles] = LUVcolors_safe(Visual.color.centerLUV, Visual.color.high_radiusLUV, scale);
    else
        [colormap, angles] = LUVcolors_safe(Visual.color.centerLUV, Visual.color.low_radiusLUV, scale);
    end

    offScreenWindow = Screen('OpenOffscreenWindow', Visual.window, Visual.patch.bg, Visual.windowRect);
    % Draw the color wheel onto the screen
    for ii = 1:length(angles)
        % Calculate the endpoint of each line in the annulus
        xStart = Visual.centerX + Visual.annulus.radiusInner * cos(angles(ii));
        yStart = Visual.centerY + Visual.annulus.radiusInner * sin(angles(ii));
        xEnd = Visual.centerX + Visual.annulus.radiusOuter * cos(angles(ii));
        yEnd = Visual.centerY + Visual.annulus.radiusOuter * sin(angles(ii));
        Screen('DrawLine', offScreenWindow, colormap(ii, :) * 255, xStart, yStart, xEnd, yEnd, 2);
    end
    
    rect = [Visual.centerX - Visual.mouseinit.radius, Visual.centerY - Visual.mouseinit.radius, ...
            Visual.centerX + Visual.mouseinit.radius, Visual.centerY + Visual.mouseinit.radius];
    Screen('FrameOval', offScreenWindow, Visual.mouseinit.color, rect, Visual.mouseinit.radiusWidth);
    
    % Save the current screen content as a texture
    texture = Screen('MakeTexture', Visual.window, Screen('GetImage', offScreenWindow));
    Screen('Close', offScreenWindow);
end


function v = StimulusDurations()
    v.FixationDuration   = 0.2; % in seconds
    v.StimulusDuration   = 0.4; % note, 1500ms in Allen's version/400ms in Estelle's
    v.RetentionDuration  = 1.0;
    v.MaskDuration       = 0.4;
    v.FeedbackDuration   = 0.5;
    v.FeedbackPenalty    = 4.0;
    v.TrialTooSlow       = 3.0;
    v.TrialTooFast       = 0.3;
    v.ResponseDuration   = 10.0;

end



function drawLineMarker(centerX, centerY, angle, color)
    global Visual
    % Calculate the start and end points of the line based on the angle
    xStart = centerX - (Visual.feedback.ticklength) * cos(angle);
    yStart = centerY - (Visual.feedback.ticklength) * sin(angle);
    xEnd = centerX + (Visual.feedback.ticklength) * cos(angle);
    yEnd = centerY + (Visual.feedback.ticklength) * sin(angle);
    Screen('DrawLine', Visual.window, color, xStart, yStart, xEnd, yEnd, Visual.feedback.linewidth);
end

function drawShortestArc(startAngle, endAngle)
    global Visual
    arcRadius = Visual.annulus.radiusOuter * 1.2;
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
        viewingdistance = 900; % 90cm
        desiredAngleDeg = 5; % 5 degree visual angle
        stim_in_mm = 2 * viewingdistance * tan((desiredAngleDeg / 2) * (pi/180));
        fiveDegVA_in_pixels = round( stim_in_mm * pixelsPerMm );

        savedConfig = currentConfig; 
        calibrationData = fiveDegVA_in_pixels; 
        save('screenCalibration.mat', 'savedConfig', 'calibrationData');
    end

end

function adjustStim(VA5deg)
    global Visual
    fiveDegCirc = [Visual.centerX - VA5deg/2, Visual.centerY - VA5deg/2, Visual.centerX + VA5deg/2, Visual.centerY + VA5deg/2];
    Screen('FillOval', Visual.window, [255 255 255], fiveDegCirc);
    DrawFormattedText(Visual.window, ...
        '5 Degrees VA Calibrated @ 90cm\nRecalibrate if incorrect.', ...
        'center', 'center', [0, 0, 0]);
    Screen('Flip', Visual.window);
    WaitSecs(.2);
    deg = VA5deg / 5;
    
    Visual.feedback.linewidth = round(deg * .08);
    Visual.feedback.ticklength = round(deg * .5);

    Visual.annulus.radiusOuter = round(deg * Visual.annulus.radiusOuter);
    Visual.annulus.radiusInner = round(deg * Visual.annulus.radiusInner);

    Visual.stim.positionradius = round(deg * 1.5);
    Visual.stim.radius = round(.5 * deg); % degrees visual angle
    Visual.stim.imaginaryradius = round(2.35 * deg); % degrees visual angle
    Visual.stim.targetcuewidth  = round(deg * .04);
    
    Visual.mouseinit.radius = round(deg * .4);
    Visual.mouseinit.radiusWidth = round(deg * .03);
    Visual.mouseinit.color = [255*.5, 255*.5, 255*.5];

    Visual.mouseinit.tooslow = 3000;
    Visual.mouseinit.toofast = 100;

    Visual.fixation.length = round(deg * .12);
    Visual.fixation.color  = [255*.5, 255*.5, 255*.5];
end

function v = initiate()
    v.patch.bg = 0 * 255;
    Screen('Preference', 'SkipSyncTests', 1); % Skip synchronization tests (not recommended for actual experiments)
    Screen('Preference', 'VisualDebugLevel', 0); % Minimal feedback
    [v.window, v.windowRect] = Screen('OpenWindow', max(Screen('Screens')), [v.patch.bg, v.patch.bg, v.patch.bg]); % Open a grey window on the main screen
    Screen('BlendFunction', v.window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Flip', v.window); % Flip to the window to update it
    [v.centerX, v.centerY] = RectCenter(v.windowRect);
    Screen('TextSize', v.window, 24);
    disp('Psychtoolbox initialized successfully');
    v.color.rotation = randi([0, 359], 1, 1);
    
    v.Keys = ResponseKeys();
    v.Durations = StimulusDurations();

    v.color.centerLUV = [54, 0.0037, -0.0275];
    v.color.high_radiusLUV = 42;
    v.color.low_radiusLUV = 23;

    v.annulus.radiusInner = 4.75;
    v.annulus.radiusOuter = 4.25;
    v.centercircle.radius = 0.63;

    

end

function [] = fixation(duration)
    global Visual
    fixCrossDimPix = Visual.fixation.length;
    
    xCoords = [-fixCrossDimPix, fixCrossDimPix, 0, 0];
    yCoords = [0, 0, -fixCrossDimPix, fixCrossDimPix];
    allCoords = [xCoords; yCoords];
    lineWidthPix = 2;
    Screen('DrawLines', Visual.window, allCoords, lineWidthPix, Visual.fixation.color, [Visual.centerX, Visual.centerY]);
    circleRadius = fixCrossDimPix; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, Visual.centerX, Visual.centerY);
    Screen('FrameOval', Visual.window, Visual.fixation.color, circleRect, lineWidthPix);
    circleRadius = 2; % Radius of the circle
    circleRect = [0, 0, circleRadius * 2, circleRadius * 2];
    circleRect = CenterRectOnPointd(circleRect, Visual.centerX, Visual.centerY);
    Screen('FrameOval', Visual.window, Visual.fixation.color, circleRect, lineWidthPix);
    rect = [Visual.centerX - Visual.mouseinit.radius, Visual.centerY - Visual.mouseinit.radius, ...
            Visual.centerX + Visual.mouseinit.radius, Visual.centerY + Visual.mouseinit.radius];
    Screen('FrameOval', Visual.window, Visual.mouseinit.color, rect, Visual.mouseinit.radiusWidth);
    if duration > 0
        Screen('Flip', Visual.window);
        WaitSecs(duration);
    end
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
        WaitSecs(2);
    else
        Screen('TextSize', Visual.window, 50);
        DrawFormattedText(Visual.window, 'Terminating Experiment.', 'center', Visual.windowRect(4)/2, [255, 255, 255]);
        Screen('Flip', Visual.window);
        WaitSecs(1);
    end
    sca; %Screen('CloseAll');
    disp('Experiment Code Finished');
end

function trials = TrialMatrix(n, sessionN, participantID, age, timestamp)
    global Visual
    itemN = [1, 2, 4, 6];

    if mod(n,length(itemN)) ~= 0
        n = n + (length(itemN)) - mod(n, length(itemN));
    end

    % Counterbalance stimulus staturation by participant ID and session N.
    IDn = str2num(participantID(2:end));
    if mod(IDn,2) == 1
        startStim = 'high';
    else
        startStim = 'low';
    end

    if mod(sessionN,2) == 1 && strcmp(startStim, 'high')
        StimSaturation = 'high';
    elseif mod(sessionN,2) == 0 && strcmp(startStim, 'high')
        StimSaturation = 'low';
    elseif mod(sessionN,2) == 1 && strcmp(startStim, 'low')
        StimSaturation = 'low';
    elseif mod(sessionN,2) == 0 && strcmp(startStim, 'low')
        StimSaturation = 'high';
    end

    % % Vectorize
    rotation = Visual.color.rotation;
    itemN = repmat(itemN', n/length(itemN),1);
    
    % 
    % % Store
    trials = table((1:n)', 'VariableNames', {'Index'});
    trials{:,'ID'} = {participantID};
    trials{:,'Age'} = age;
    trials{:,'Session'} = sessionN;
    trials{:,'StartTime'} = {timestamp};
    trials{:,'StimulusSaturation'} = {StimSaturation};
    trials{:,'WheelSaturation'} = {'high'};
    trials{:,'ItemN'} = itemN;
    trials{:,'WheelRotation'} = rotation;
    trials{:,'TargetIndex'} = 0;
    trials{:,'StimulusColorAngles'} = {nan};
    trials{:,'StimulusItemLocations'} = {nan};
    
    % Loop through randomized indicies
    for ii = 1:n
        trials{ii,'StimulusColorAngles'} = {randColors(trials.ItemN(ii))};
        trials{ii,'StimulusItemLocations'} = {(0:trials.ItemN(ii)-1) * (360 / trials.ItemN(ii)) + randi([0, (360 / trials.ItemN(ii)) - 1])};
        trials{ii,'TargetIndex'} = randi([1,trials.ItemN(ii)]);
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

    % Randomize trials
    trials = trials(randperm(size(trials,1)),:);
    trials.Index = (1:size(trials,1))';


end











function [colorMap, angles, valid] = LUVcolors_safe(centerLUV, radius, scale)
    n = 360 * scale;
    angles = linspace(0, 2*pi, n+1)';
    angles(end) = [];

    luv = zeros(n,3);
    luv(:,1) = centerLUV(1);
    luv(:,2) = centerLUV(2) + radius*cos(angles);
    luv(:,3) = centerLUV(3) + radius*sin(angles);

    [colorMap, ~, valid] = luv2rgb_check(luv);
end

function [rgb, linRGB, inGamut] = luv2rgb_check(luv)
    % luv is Nx3: [L u v]
    % Returns:
    %   linRGB  = linear RGB before gamma correction
    %   rgb     = gamma-corrected sRGB, only valid when inGamut = true
    %   inGamut = all linear RGB channels in [0,1]

    % D65 whitepoint, matching your colorspace() function
    WhitePoint = [0.950456, 1.0, 1.088754];
    WhitePointU = (4*WhitePoint(1)) / (WhitePoint(1) + 15*WhitePoint(2) + 3*WhitePoint(3));
    WhitePointV = (9*WhitePoint(2)) / (WhitePoint(1) + 15*WhitePoint(2) + 3*WhitePoint(3));

    L = luv(:,1);
    u = luv(:,2);
    v = luv(:,3);

    % L*u*v* -> XYZ
    fY = (L + 16) / 116;
    Y = invf_local(fY) * WhitePoint(2);

    U = u ./ (13*L + 1e-12) + WhitePointU;
    V = v ./ (13*L + 1e-12) + WhitePointV;

    X = -(9 .* Y .* U) ./ (((U - 4) .* V) - (U .* V));
    Z = (9 .* Y - 15 .* V .* Y - V .* X) ./ (3 .* V);

    XYZ = [X Y Z];

    % XYZ -> linear RGB
    T = [ 3.2406, -1.5372, -0.4986;
         -0.9689,  1.8758,  0.0415;
          0.0557, -0.2040,  1.0570];

    linRGB = XYZ * T';

    % TRUE gamut test: no repair, no clipping
    tol = 1e-9;
    inGamut = all(linRGB >= -tol & linRGB <= 1+tol, 2);

    % Gamma-correct only valid values
    rgb = nan(size(linRGB));
    rgb(inGamut,:) = gamma_local(linRGB(inGamut,:));
end

function y = invf_local(x)
    y = x.^3;
    idx = y < 0.008856;
    y(idx) = (x(idx) - 4/29) * (108/841);
end

function srgb = gamma_local(lin)
    srgb = zeros(size(lin));
    idx = lin <= 0.0031306684425005883;
    srgb(idx) = 12.92 * lin(idx);
    srgb(~idx) = 1.055 * lin(~idx).^(1/2.4) - 0.055;
end


% Check LUV color maps show in sRGB format
% check = 0;
% ii = 129;
% while sum(check) < 360
%     ii = ii - 1;
%     [~,~,check] = LUVcolors_safe(Visual.color.centerLUV, ii, 1);
% end
%Visual.color.high_radiusLUV = 42;
%Visual.color.low_radiusLUV = 21;