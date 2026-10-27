function Exp_ChangeDetection_2
    % N-trial change-detection Experiment
    % Log Accuracy and RT

    % 1-How to preset conditions so that change and no-change trials are
    % balanced whever Trial-N is changed
    %2-How to have multiple stimuli with free to set:
        % - location
        % - size
        % - color
        % - shape
        % - orientation
    %What if multiple dimensions can change, but follows a odd-one-out
    %style rule of change, that next trial only has one change in a single feature dimension



    %2-Display cumulative accuracy and errors
    
    % Initialise PTB
    clear; close all; clc;
    AssertOpenGL;
    Screen('Preference','SkipSyncTests', 0); % skip sync
    KbName('UnifyKeyNames'); % recognise keyboard types
    
    bgColor = 128;
    scr      = max(Screen('Screens'));
    [win, winRect] = Screen('OpenWindow', scr, bgColor);
    
    Priority(MaxPriority(win));
    Screen('TextSize', win, 24);
    
    % make sure PTB shuts down even on errors:
    cleanupObj = onCleanup(@()gotoEnd(win));
    
    % Constants
    msgXY = [winRect(3)/2, winRect(4)*.7];
    dotXY = [winRect(3)/2, winRect(4)/2];
    dotRadius = 30;
    setSizes   = [1 2 4 6];     % run each of these once (or shuffle later)
    cenCircle    = 150;           % radius in pixels (distance from screen centre)
   
    % fixation
    fixL    = 40;   % length
    fixT  = 4;    % thickness
    fixC = 255;  %color
    
    colors   = [ 255  0   0 ;   % red
                    0 255   0 ;   % green
                    0   0 255 ];  % blue
    
    codeS = KbName('s');
    codeQ = KbName('q');
    codeY = KbName('y');
    codeN = KbName('n');
    
    keyMask = zeros(256,1);
    keyMask([codeS codeQ codeY codeN]) = 1;
    KbQueueCreate([], keyMask);
    KbQueueStart;
    
    % Instruction
    instr = ['Press **S** to begin a trial.\n\n' ...
             'A colored dot will appear for 400 ms.\n' ...
             'After a short rentention, a probe dot will appear.\n\n' ...
             'Press **Y** if the probe changed color,\n' ...
             'press **N** if no change.\n' ...
             'Press **Q** to quit at any time.'];
    
    DrawFormattedText(win, instr, 'center', 'center', 255, 60);
    Screen('Flip', win);
    
    % Check input
    while true
        [pressed, fp] = KbQueueCheck;
        if pressed
            if fp(codeQ) > 0
                return; % In case want to quit
            elseif fp(codeS) > 0
                KbQueueFlush;
                break; % trial start
            end
        end
    end
    
    % Trials Begin~

    nTrials = 4;
    allResults = table();
    nCorrect = 0;
    KbQueueFlush;
    
    for t = 1:nTrials

        setSize = setSizes(mod(t-1, numel(setSizes))+1);   % cycles through set-size
    
        Screen('FillRect', win, bgColor);   

        % and Fixation as rectangle fill, try line later          
        Screen('FillRect', win, fixC, ... 
        [dotXY(1)-fixL/2, dotXY(2)-fixT/2, ...
        dotXY(1)+fixL/2, dotXY(2)+fixT/2]);
        
        Screen('FillRect', win, fixC, ...
        [dotXY(1)-fixT/2, dotXY(2)-fixL/2,  ...
        dotXY(1)+fixT/2, dotXY(2)+fixL/2]);
                    
        Screen('Flip', win); % show fixation
        WaitSecs(1.0); % for 1000ms
        
        % -------- pick stimulus positions & colours ---------------------------
        stimXY  = ringCoords(setSize, dotXY, cenCircle);
        stimCol = colors(randi(3, setSize, 1), :);          % random colour per item
        
        % choose one item to probe
        probeId = randi(setSize);
        probeXY   = stimXY(probeId, :);
        probeCol  = stimCol(probeId, :);
        
        % decide change vs no-change exactly as before
        if rand < 0.5               % same
            newProbeCol = probeCol;  isChange = 0;  correctKey = codeN;
        else                         % change
            tmp = probeCol;
            while all(tmp == probeCol)
                tmp = colors(randi(3), :);           % ensure different colour
            end
            newProbeCol = tmp;         isChange = 1; correctKey = codeY;
        end

    
        % Stim for 400ms
        Screen('FillRect', win, bgColor);
        for i = 1:setSize
            drawDot(win, stimXY(i,:), dotRadius, stimCol(i,:));
        end
        Screen('Flip', win);
        WaitSecs(0.400);
        
        % Retention for 1000ms
        Screen('FillRect', win, bgColor);
        Screen('Flip', win);
        WaitSecs(1.0);
        
        % Sustained probe
        Screen('FillRect', win, bgColor);
        drawDot(win, probeXY, dotRadius, newProbeCol);
        probeTime = Screen('Flip', win);
        KbQueueFlush;
        
        % Check response
        respKey = NaN; RT = NaN;
    
        while true
            [pressed, fp] = KbQueueCheck;
            
            if pressed
    
                if fp(codeQ) > 0; return;
    
                elseif fp(codeY) > 0 || fp(codeN) > 0
                    respKey = find(fp); % numeric key-code
                    RT = (fp(respKey) - probeTime) * 1000;
                    break;
                end

            end

        end
        
        % Calculate %correct
        correct = (respKey == correctKey); % match = correct (1)
        nCorrect = nCorrect + correct;
        accPerc = (nCorrect/t)*100;q
    
        trialRes = table(t, setSize, probeId, stimCol(probeId,:), newProbeCol, isChange, respKey, correct, RT, ...
        'VariableNames',{'Trial','SetSize','TargetID', 'StimulusColor', 'ProbeColor', 'Change','Key','Correct','RT'});
        allResults = [allResults; trialRes];
    
    % Feedback screen
        fbBase = sprintf('Trial %d/%d: %s   (RT %.0f ms)\nAccuracy: %.1f %%', ...
                          t,nTrials, ternary(correct,'Correct','Incorrect'), RT, accPerc);
    
        if t==nTrials
            fbBase = sprintf('%s\n\nThe experiment is now complete.\nPress Q to quit.', fbBase);
        else
            fbBase = sprintf('%s\n\nPress S for the next trial or Q to quit.', fbBase);
        end
    
        fbColor = ternary(correct, [0 255 0], [255 0 0]);  % green / red
        Screen('FillRect', win, bgColor);
        DrawFormattedText(win, fbBase, 'center', 'center', fbColor);
        Screen('Flip', win);
        
        KbQueueFlush;
    
        while true

            [p, fp] = KbQueueCheck;

            if p
    
                if fp(codeQ) > 0
                    saveData(allResults)
                    return
                end
    
                if t < nTrials && fp(codeS)
                    KbQueueFlush
                    break
                end
                
            end

        end

    end % end n trial loop (for)
    
        saveData(allResults)

    end
    
% Helper functions
function xy = ringCoords(n, centreXY, radius)
% Return n×2 matrix of [x y] coordinates evenly spaced on a circle.
angles = linspace(0, 2*pi, n+1);    % n+1 so last = 360°; discard it
angles(end) = [];
xy = [ centreXY(1) + radius * cos(angles).' , ...
       centreXY(2) + radius * sin(angles).' ];
end

function drawDot(win, centreXY, radius, rgb)
    Screen('FillOval', win, rgb, ...
    CenterRectOnPoint([0 0 2*radius 2*radius], centreXY(1), centreXY(2)));
end

function txt = ternary(cond, a, b)
    txt = a; if ~cond, txt = b; end
end

function saveData(res)
    outDir = 'CD_Exp_data';
    if ~exist(outDir,'dir'), mkdir(outDir); end

        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        fname = fullfile(outDir, [timestamp '_CD.mat']);

        save(fname,'res');
        fprintf('Saved %d trials to %s\n', height(res), fname);
end

function gotoEnd(~)
KbQueueRelease;
sca;
Priority(0);
end
