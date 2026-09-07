function axhandle = setfig24;
% ==========================================================================
% setfig (Small):
% Script to construct a 6 x 4 figure object and set default properties.
% Returns axis handles in axhandle, figure handle in fhandle.
%===========================================================================
fhandle = figure;
pw = 21;  % Reference figure sizes for computing positions.
%pl = 29; 
pl = 31;  % Bigger than A4!
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
            0   25 4 4  
            5.2 25 4 4  
            10.4 25 4 4
            15.4 25 4 4

            0   20 4 4  
            5.2 20 4 4  
            10.4 20 4 4
            15.4 20 4 4

             0   15 4 4  
            5.2  15 4 4  
            10.4 15 4 4
            15.4 15 4 4

              0 10 4 4  
            5.2 10 4 4  
            10.4 10 4 4
            15.4 10 4 4

            0   5 4 4  
            5.2 5 4 4  
            10.4 5 4 4
            15.4 5 4 4];

%            0   0 4 4  
%            5.2 0 4 4  
%            10.4 0 4 4
%            15.4 0 4 4
%]; % Centimeters
%positions = flipud(positions); % These were bottom to top.
positions(:,1) = positions(:,1) + 1;
positions(:,2) = positions(:,2) + 1;
positions(:,1) = positions(:,1) / pw;
positions(:,2) = positions(:,2) / pl;
positions(:,3) = positions(:,3) / pw;
positions(:,4) = positions(:,4) / pl;  % Normalized Units
axhandle=[];
for i=1:20
    axh=axes('Position', positions(i,:));
    axhandle=[axhandle,axh];
end;
