function axhandle = setfig3;
% ==========================================================================
% setfig3:
% Script to construct a 3 x 1 figure object and set default properties.
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
             'DefaultAxesYLim', [0,1.0], ...
             'PaperUnits', 'centi', ...
             'PaperType', 'a4', ...
             'PaperPosition', [1, 1, 19, 27], ...
             'Position', [120, 10, 360, 510]);
%  Add these to list ablove to fix axes.
%             'DefaultAxesXLim', [-50,10]
%             'DefaultAxesYLim', [.175,.6]
set(fhandle, 'DefaultLineLineWidth', 1.0, ...
             'DefaultLineColor', [1,1,1], ...
             'DefaultLineLineStyle', '-', ...
             'DefaultLineMarkerSize', 4);
set(fhandle, 'DefaultTextFontSize', 12);
figure(fhandle);
positions =[ 1.5 15 5 5
             8.5 15 5 5
             15.5 15 5 5];  % Centimeters
positions(:,1) = positions(:,1) / pw;
positions(:,2) = positions(:,2) / pl;
positions(:,3) = positions(:,3) / pw;
positions(:,4) = positions(:,4) / pl;  % Normalized Units
axhandle=[];
for i=1:3
    axh=axes('Position', positions(i,:));
    axhandle=[axhandle,axh];
end;
