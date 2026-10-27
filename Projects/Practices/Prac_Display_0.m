%% Section 1

clear; close all; clc;
format shortg
KbName('UnifyKeyNames'); %How matlab recognise Keyboard types

%% Section 2

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS'); % When the session began
ID = input( 'Please enter your initials', 's')