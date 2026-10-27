function Prac_CD_Log_2
% Single trial change detection test, logs save accuracy and RT

% ----------- PTB initialise -----------------------------------------
clear; close all; clc;
AssertOpenGL;
Screen('Preference','SkipSyncTests', 1); % skip sync
KbName('UnifyKeyNames'); % recognise keyboard types

bgColor = 128;
scr      = max(Screen('Screens'));
[win, winRect] = Screen('OpenWindow', scr, bgColor);

Priority(MaxPriority(win));
Screen('TextSize', win, 24);

% make sure PTB shuts down even on errors:
cleanupObj = onCleanup(@()gotoEnd(win));

% ----------- CONSTANTS & KEYS -------------------------------------------
dotXY = [winRect(3)/2, winRect(4)/2];
dotRadius = 30;

% fixation
fixL    = 40;   % length
fixT  = 4;    % thickness
fixC = 255;  %color

colors   = [ 255  0   0 ;   % red
                0 255   0 ;   % green
                0   0 255 ];  % blue

code.S = KbName('s');
code.Q = KbName('q');
code.Y = KbName('y');
code.N = KbName('n');

keyMask          = zeros(256,1);
keyMask([code.S code.Q code.Y code.N]) = 1;
KbQueueCreate([], keyMask);
KbQueueStart;

% ----------- INSTRUCTION SCREEN -----------------------------------------
instr = ['Press **S** to begin a trial.\n\n' ...
         'A colored dot will appear for 400 ms.\n' ...
         'After a short rentention, a probe dot will appear.\n\n' ...
         'Press **Y** if the probe changed color,\n' ...
         'press **N** if no change.\n' ...
         'Press **Q** to quit at any time.'];

DrawFormattedText(win, instr, winRect(3)/2, winRect(4)*.7, 255, 60);
Screen('Flip', win);

% ----------- WAIT FOR S OR Q --------------------------------------------
while true
    [pressed, fp] = KbQueueCheck;
    if pressed
        if fp(code.Q) > 0
            return;                               % abort before trial
        elseif fp(code.S) > 0
            KbQueueFlush;

            Screen('FillRect', win, bgColor);     % blank background

            Screen('FillRect', win, fixC, ...
            [winRect(3)/2-fixL/2   winRect(4)/2-fixT/2  ...
            winRect(3)/2+fixL/2   winRect(4)/2+fixT/2]);

            Screen('FillRect', win, fixC, ...
            [winRect(3)/2-fixT/2   winRect(4)/2-fixL/2  ...
            winRect(3)/2+fixT/2   winRect(4)/2+fixL/2]);

Screen('Flip', win);                  % show fixation
WaitSecs(1.0);                        % hold for 1000 ms


            break;                                % start trial
        end
    end
end

% ===================== TRIAL TIMELINE ====================================

% ---- pick sample & probe colors ---------------------------------------
sampleIdx = randi(3);
if rand < 0.5                                     % SAME trial
    probeIdx    = sampleIdx;
    correctKey  = code.N;
    isChange    = 0;
else                                              % CHANGE trial
    probeIdx = sampleIdx;
    while probeIdx == sampleIdx                   % ensure different
        probeIdx = randi(3);
    end
    correctKey  = code.Y;
    isChange    = 1;
end

% ---- draw SAMPLE (400 ms) ----------------------------------------------
drawDot(win, dotXY, dotRadius, colors(sampleIdx,:));
Screen('Flip', win);
WaitSecs(0.400);

% ---- blank during retention (1 s) --------------------------------------
Screen('FillRect', win, bgColor);
Screen('Flip', win);
WaitSecs(1.0);

% ---- draw PROBE (stays until response) ---------------------------------
drawDot(win, dotXY, dotRadius, colors(probeIdx,:));
probeOnset = Screen('Flip', win);                 % time-stamp for RT

% ---- collect Y / N / Q --------------------------------------------------
KbQueueFlush;
respKey = NaN; RT = NaN;

while true
    [pressed, fp] = KbQueueCheck;
    if pressed
        if fp(code.Q) > 0                       % abort during probe
            return;
        elseif fp(code.Y) > 0 || fp(code.N) > 0
            respKey = find(fp);                % numeric key-code
            RT = (fp(respKey) - probeOnset) * 1000; % ms
            break;
        end
    end
end

% ---- evaluate accuracy --------------------------------------------------
correct = (respKey == correctKey);              % 1 = correct, 0 = incorrect

% ---- feedback screen (1.2 s) -------------------------------------------
fbText   = sprintf('%s  (RT = %.0f ms)', ...
                   ternary(correct,'Correct','Incorrect'), RT);
fbColor = ternary(correct, [0 255 0], [255 0 0]);  % green / red
Screen('FillRect', win, bgColor);
DrawFormattedText(win, fbText, 'center', 'center', fbColor);
Screen('Flip', win);
WaitSecs(2.0);

% -------------------- SAVE RESULT ----------------------------------------
result = table(sampleIdx, probeIdx, isChange, respKey, correct, RT, ...
               'VariableNames',{'Sample','Probe','Change','Key','Correct','RT_ms'});

saveData(result);
% after saving the function exits → onCleanup closes PTB
end  % ================= END OF MAIN FUNCTION =============================



% ====================  HELPER FUNCTIONS  =================================
function drawDot(win, centreXY, radius, rgb)
Screen('FillOval', win, rgb, ...
       CenterRectOnPoint([0 0 2*radius 2*radius], centreXY(1), centreXY(2)));
end

function txt = ternary(cond, a, b)
txt = a; if ~cond, txt = b; end
end

function saveData(res)
    outDir = 'CD_data';
    if ~exist(outDir,'dir'), mkdir(outDir); end

    timestamp = datestr(now,'yyyymmdd_HHMMSS');
    fname     = fullfile(outDir, [timestamp '_CD.mat']);

    save(fname,'res');
    fprintf('Saved to %s\n', fname);
end

function gotoEnd(~)
KbQueueRelease;
sca;
Priority(0);
end
