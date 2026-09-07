function axhandle = setfig8narrow;
% ==========================================================================
% setfig8narrow (half a 4 x 4 plot)
% Script to construct a 4 x 4 figure object and set default properties.
% Returns axis handles in axhandle, figure handle in fhandle.
%===========================================================================
fhandle = figure;
pw = 21;  % Reference figure sizes for computing positions.
pl = 29;
set(0,       'ScreenDepth', 1); 
set(fhandle, 'DefaultAxesBox', 'on', ...
             'DefaultAxesLineWidth', 1.5, ...
             'DefaultAxesFontSize', 12, ...
             'DefaultAxesXLim', [0,Inf], ...
             'DefaultAxesYLim', [-Inf,Inf], ...
             'PaperUnits', 'centi', ...
             'PaperType', 'a4', ...
             'PaperPosition', [1, 1, 19, 27], ...
             'Position', [120, 10, 360, 510]);
set(fhandle, 'DefaultLineLineWidth', 0.5, ...
             'DefaultLineColor', [1,1,1], ...
             'DefaultLineLineStyle', '-', ...
             'DefaultLineMarkerSize', 6);
set(fhandle, 'DefaultTextFontSize', 12);
figure(fhandle);
positions =[
0    20 3.5 3.5
4.1  20 3.5 3.5
0    16  3.5 3.5
4.1  16  3.5 3.5
0    12 3.5 3.5
4.1  12 3.5 3.5
0    8  3.5 3.5
4.1  8  3.5 3.5];
%9    8  3.5 3.5
%13.5 8  3.5 3.5]; % Centimeters
%positions = flipud(positions); % These were bottom to top.
positions(:,1) = positions(:,1) + 2.5;
positions(:,2) = positions(:,2);
positions(:,1) = positions(:,1) / pw;
positions(:,2) = positions(:,2) / pl;
positions(:,3) = positions(:,3) / pw;
positions(:,4) = positions(:,4) / pl;  % Normalized Units
axhandle=[];
for i=1:8 %%   1:16
    axh=axes('Position', positions(i,:));
    axhandle=[axhandle,axh];
end;
