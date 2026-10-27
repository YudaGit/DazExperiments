function axhandle = setfig8;
% ==========================================================================
% setfig8:
% Script to construct a 3 x 2 figure object and set default properties.
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
             'PaperPositionMode', 'auto', ...
             'Position', [120, 10, 360, 510]);
set(fhandle, 'DefaultLineLineWidth', 0.5, ...
             'DefaultLineColor', [1,1,1], ...
             'DefaultLineLineStyle', '-', ...
             'DefaultLineMarkerSize', 6);
set(fhandle, 'DefaultTextFontSize', 12);
figure(fhandle);
positions =[ 3.5 23.0 6.5 5.5
             11.0 23.0 6.5 5.5
             3.5  17.0 6.5 5.5
             11.0 17.0 6.5 5.5
             3.5  11.0 6.5 5.5
             11.0 11.0 6.5 5.5
             3.5  5.0 6.5 5.5
             11.0 5.0 6.5 5.5];


positions(:,1) = positions(:,1) / pw;
positions(:,2) = positions(:,2) / pl;
positions(:,3) = positions(:,3) / pw;
positions(:,4) = positions(:,4) / pl;  % Normalized Units

axhandle=[];
for i=1:8
    axh=axes('Position', positions(i,:));
    axhandle=[axhandle,axh];
end;
