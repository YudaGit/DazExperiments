%% Section 1

clear; close all; clc;
AssertOpenGL;
Screen('Preference','SkipSyncTests', 0);  % <‑‑ bypass the sync safety net
format shortg
KbName('UnifyKeyNames'); %How matlab recognise Keyboard types

%% Section 3

try
    screenID = max(Screen('Screens'));
    [win, rect] = Screen('OpenWindow', screenID, 128); % gray background
    Priority(MaxPriority(win));
    Screen('TextSize',win,40);
    DrawFormattedText(win,'Hello world','center','center',255);
    Screen('Flip',win);  
    WaitSecs(2); % show for 2s
catch ME
    sca; rethrow(ME);
end
sca;  % close!