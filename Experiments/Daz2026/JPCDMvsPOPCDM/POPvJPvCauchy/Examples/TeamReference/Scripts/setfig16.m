function axhandle = setfig16;
% ==========================================================================
% setfig (Small):
% Script to construct a 4 x 4 figure object and set default properties.
% Returns axis handles in axhandle, figure handle in fhandle.
%===========================================================================
fhandle = figure;
pw = 21;  % Reference figure sizes for computing positions.
pl = 29;
set(0,       'ScreenDepth', 1); 
set(fhandle, 'DefaultAxesBox', 'on', ...
             'DefaultAxesLineWidth', 1.5, ...
             'DefaultAxesFontSize', 10, ...
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
set(fhandle, 'DefaultTextFontSize', 10);
figure(fhandle);
positions =[
0    21.5 3.5 3.5
4.5  21.5 3.5 3.5
9    21.5 3.5 3.5
13.5 21.5 3.5 3.5
0    17  3.5 3.5
4.5  17  3.5 3.5
9    17  3.5 3.5
13.5 17  3.5 3.5
0    12.5 3.5 3.5
4.5  12.5 3.5 3.5
9    12.5 3.5 3.5
13.5 12.5 3.5 3.5
0    8  3.5 3.5
4.5  8  3.5 3.5
9    8  3.5 3.5
13.5 8  3.5 3.5]; % Centimeters
%positions = flipud(positions); % These were bottom to top.
positions(:,1) = positions(:,1) + 2.5;
positions(:,2) = positions(:,2);
positions(:,1) = positions(:,1) / pw;
positions(:,2) = positions(:,2) / pl;
positions(:,3) = positions(:,3) / pw;
positions(:,4) = positions(:,4) / pl;  % Normalized Units
axhandle=[];
for i=1:16
    axh=axes('Position', positions(i,:));
    axhandle=[axhandle,axh];
end;
