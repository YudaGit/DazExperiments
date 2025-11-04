clear; close all; clc;
AssertOpenGL;
Screen('Preference','SkipSyncTests', 1);  % <‑‑ bypass the sync safety net
format shortg
KbName('UnifyKeyNames'); %How matlab recognise Keyboard types

% -------------------Adjustable parameters------------------
msgText      = 'Press D to show a red dot.  Press Q to quit.';   % message string
msgXY        = [1920, 1080];                 % [x y] *in pixels*     (0,0 = top-left)
keyQuit  = 'q';                          % quit script
keyShowStim   = 'd';                % response key to make something happen
keyKillStim = 'k';
dotXY        = [1920, 1000];          % dot centre [x y] in pixels from left/top
dotRadius    = 30;                    % dot radius in pixels

bgColor      = 128;                   % background
textColor    = 255;                   % white text
dotColor     = [255  0  0];           % red dot
%------------------------------------------------------------------------

try

    screenID = max(Screen('Screens')); % check and use external monitor
    [win, rect] = Screen('OpenWindow', screenID, bgColor); % initiate full screen window
    Priority(MaxPriority(win)); % bump process priority
    
    % Map key
    codeQuit = KbName(keyQuit);
    codeShowStim = KbName(keyShowStim);
    codeKillStim = KbName(keyKillStim);

    % Build 256-element key mask: 1 = watch this key
    keyMask = zeros(256,1);
    keyMask([codeQuit, codeShowStim, codeKillStim]) = 1;
    KbQueueCreate([], keyMask);
    KbQueueStart;

    dotShown = false; % flag variable
        
    while true

    % Step1 Poll keyboard (non-blocking)
        [pressed, firstPress] = KbQueueCheck;
        if pressed

            if firstPress(codeShowStim)  
                dotShown = true; 
                KbQueueFlush; % clear queue so it triggers only once
            elseif firstPress(codeKillStim)
                dotShown = false;
                KbQueueFlush;
            elseif firstPress(codeQuit)
                KbQueueFlush;
                break;           
                
            end
   
        end

    % Step2 Draw current frame
        Screen('FillRect', win, bgColor) % clear frame
        DrawFormattedText(win, msgText, 'center', msgXY(2), textColor); % If Anchoring text block at its centre
        % Draw text --Coordinates = upper-left corner of first letter
        %Screen('DrawText', win, msgText, msgXY(1), msgXY(2), textColor);
        
    % Draw dot if Dot key was pressed
        if dotShown
            ovalRect = CenterRectOnPoint([0, 0, dotRadius*2, dotRadius*2], ...
                                          dotXY(1), dotXY(2));
            Screen('FillOval', win, dotColor, ovalRect);
        end
        Screen('Flip', win); % present this frame

    end

catch ME

    sca; rethrow(ME);      % <-- tidy up even on error

end

sca;                       % <-- and here on clean exit