function axhandle = setfig2;
% ==========================================================================
% setfig2:
% Script to construct a 2 x 1 figure object and set default properties.
% Returns axis handles in axhandle, figure handle in fhandle.
%===========================================================================
fhandle = figure;
pw = 21;  % Reference figure sizes for computing positions.
pl = 29;
set(0,       'ScreenDepth', 1); 
set(fhandle, 'DefaultAxesBox', 'on', ...
             'DefaultAxesLineWidth', 1.5, ...
             'DefaultAxesFontSize', 12, ...
             'DefaultAxesXLim', [0,2.5], ...
             'DefaultAxesYLim', [0,Inf], ...
             'PaperUnits', 'centi', ...
             'PaperType', 'usletter', ...
             'PaperPosition', [1, 1, 19, 27], ...
             'Position', [120, 10, 360, 510]);
%  Add these to list above to fix axes.
%             'DefaultAxesXLim', [-50,10]
%             'DefaultAxesYLim', [.175,.6]
set(fhandle, 'DefaultLineLineWidth', 1.25, ...
             'DefaultLineColor', [1,1,1], ...
             'DefaultLineLineStyle', '-', ...
             'DefaultLineMarkerSize', 10);  % 6
set(fhandle, 'DefaultTextFontSize', 12);    % 15
figure(fhandle);
positions =[5.5 18 10 9
            5.5 6 10 9];  % Centimeters
positions(:,1) = positions(:,1) / pw;
positions(:,2) = positions(:,2) / pl;
positions(:,3) = positions(:,3) / pw;
positions(:,4) = positions(:,4) / pl;  % Normalized Units
axhandle=[];
for i=1:2
    axh=axes('Position', positions(i,:));
    axhandle=[axhandle,axh];
end;
