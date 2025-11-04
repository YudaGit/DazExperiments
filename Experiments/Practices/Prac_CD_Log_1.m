clear; close all; clc;

% ---------- PTB initialisation

AssertOpenGL;
Screen('Preference','SkipSyncTests', 1);  % <‑‑ bypass the sync safety net
format shortg
KbName('UnifyKeyNames'); %How matlab recognise Keyboard types
bgColour = 128;


% -------------------Adjustable parameters------------------
msgInitial = ['Press S to begin a trial where one color dot will be shown for 400ms,' ...
    'after a brief delay, another color dot will be shown. Please respond with Y if the' ...
    'second dot has changed color, or respond with N if it has not changed color'];
msgResult = ['Below shows the outcome of your response:']
msgXY = [1920, 1080];
keyStart = 's';
keyQuit = 'q';
keyYes = 'y';
keyNo = 'n';
dotXY = [1920, 1000];          % dot centre [x y] in pixels from left/top
dotRadius = 30;                    % dot radius in pixels

dotColorR = [255, 0, 0];           % red dot
dotColorG = [0, 255, 0];           % green dot
dotColorB = [0, 0, 255];           % blue dot

stimDuration = 400;
retentionDuration = 1000; % the time between stim and probe
probeDuration = ;% not sure how to let to probe display forever


%------------------------------------------------------------------------

try

    screenID = max(Screen('Screens')); % check and use external monitor
    [win, rect] = Screen('OpenWindow', screenID, bgColor); % initiate full screen window
    Priority(MaxPriority(win)); % bump process priority
    
    % Map key
    codeStart = KbName(keyStart);
    codeQuit = KbName(keyQuit);
    codeRespY = KbName(keyYes);
    codeRespN = KbName(keyNo);

    % Build 256-element key mask: 1 = watch this key
    keyMask = zeros(256,1);
    keyMask([codeStart, codeQuit, codeRespY, codeRespN]) = 1;
    KbQueueCreate([], keyMask);
    KbQueueStart;

    stimShown = false; % flag variable
    probeShown = false; % flag variable

    while true

    % Step1 Poll keyboard (non-blocking)
        [pressed, firstPress] = KbQueueCheck;
        if pressed

            if firstPress(codeStart)
                KbQueueFlush; % clear queue so it triggers only once
                WaitSecs = 1.000; 
                dotShown = true; 
            end




            if firstPress(codeQuit) 
                break;           
                KbQueueFlush;
            end
   
        end

    % Step2 Draw current frame
        Screen('FillRect', win, bgColor) % clear frame

    % Draw text --Coordinates = upper-left corner of first letter
    %Screen('DrawText', win, msgText, msgXY(1), msgXY(2), textColor);

    % If Anchoring text block at its centre
        DrawFormattedText(win, msgInitial, 'center', msgXY(2), textColor);
    
    % Draw dot if Dot key was pressed
        if dotShown
            ovalRect = CenterRectOnPoint([0, 0, dotRadius*2, dotRadius*2], ...
                                          dotXY(1), dotXY(2));
            Screen('FillOval', win, dotColor, ovalRect); % dot color here should randomly draw one of the 3 presets
        end
        Screen('Flip', win); % present this frame

    % Terminate dot if killStimuli key was pressed
    
    end

catch ME

    sca; rethrow(ME);      % <-- tidy up even on error

end

sca;                       % <-- and here on clean exit