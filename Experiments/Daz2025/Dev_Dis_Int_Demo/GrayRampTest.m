function GrayRampTest
% ------------------------------------------------------------
% PTB demo to compare 8-bit vs float/10-bit ramps
% Daz Liu learning edition :)
% ------------------------------------------------------------
clear; close all; clc;
sca; Screen('CloseAll');
KbName('UnifyKeyNames');

% ---------- [1] ask user which mode ----------
choice = questdlg('Framebuffer mode?', 'Gray Ramp','Float/10-bit','Standard 8-bit','Float/10-bit');
useFloat = strcmp(choice,'Float/10-bit');

% ---------- [2] open window ----------
screenId = max(Screen('Screens'));
bg01 = 0.5;   % neutral gray background (0–1)
if useFloat
    try
        PsychImaging('PrepareConfiguration');
        PsychImaging('AddTask','General','FloatingPoint32BitIfPossible');
        PsychImaging('AddTask','General','EnableNative10BitFramebuffer');
        [win, winRect] = PsychImaging('OpenWindow', screenId, bg01);
    catch
        warning('Fallback to 8-bit window.');
        [win, winRect] = Screen('OpenWindow', screenId, bg01*255);
    end
else
    [win, winRect] = Screen('OpenWindow', screenId, bg01*255);
end

ifi = Screen('GetFlipInterval', win);
fprintf('Refresh rate: %.2f Hz (%.2f ms/frame)\n', 1/ifi, ifi*1000);

% ---------- [3] make gradient texture ----------
[x, ~] = meshgrid(linspace(0,1,2048), 1:50);
img = repmat(x, [1,1,3]);     % same gray on R,G,B
tex = Screen('MakeTexture', win, img);

% ---------- [4] display ----------
Screen('DrawTexture', win, tex, [], winRect);
DrawFormattedText(win, ...
    sprintf('Mode: %s\nPress ESC to quit', ...
        ternary(useFloat,'Float/10-bit','8-bit standard')), ...
    'center', winRect(4)*0.9, [1 1 1]);
Screen('Flip', win);

% ---------- [5] wait for ESC ----------
while true
    [keyDown,~,kc] = KbCheck;
    if keyDown && kc(KbName('ESCAPE'))
        break;
    end
    WaitSecs(0.01);
end
sca;
end

function out = ternary(cond,a,b)
if cond, out=a; else, out=b; end
end
