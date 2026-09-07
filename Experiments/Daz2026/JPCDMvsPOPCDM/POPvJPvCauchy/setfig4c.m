function axhandle = setfig4c;
% ==========================================================================
% setfig4:
% Script to construct a 4 x 1 figure object and set default properties.
% Returns axis handles in axhandle, figure handle in fhandle.
%===========================================================================
fhandle = figure;
pw = 21;  % Reference figure sizes for computing positions.
pl = 29;
set(0,       'ScreenDepth', 1); 
set(fhandle, 'DefaultAxesBox', 'on', ...
             'DefaultAxesLineWidth', 1.5, ...
             'DefaultAxesFontSize', 13, ...
             'DefaultAxesXLim', [0,Inf], ...
             'DefaultAxesYLim', [-Inf,Inf], ...
             'PaperUnits', 'centi', ...
             'PaperType', 'a4', ...
             'PaperPosition', [1, 1, 19, 27], ...
             'Position', [120, 10, 360, 510]);
set(fhandle, 'DefaultLineLineWidth', 0.5, ...
             'DefaultLineColor', [1,1,1], ...
             'DefaultLineLineStyle', '-', ...
             'DefaultLineMarkerSize', 2);
set(fhandle, 'DefaultTextFontSize', 13);
figure(fhandle);
positions =[7.5 16.0 3.5 3.5
            7.5 12.0 3.5 3.5
            7.5  8.0 3.5 3.5
            7.5  4.0 3.5 3.5];
positions(:,1) = positions(:,1) + 2;
positions(:,2) = positions(:,2) + 4;
positions(:,1) = positions(:,1) / pw;
positions(:,2) = positions(:,2) / pl;
positions(:,3) = positions(:,3) / pw;
positions(:,4) = positions(:,4) / pl;  % Normalized Units
axhandle=[];
for i=1:4
    axh=axes('Position', positions(i,:));
    axhandle=[axhandle,axh];
end;
