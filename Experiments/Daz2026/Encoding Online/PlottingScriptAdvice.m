% Example code for publicaiton quality plots in matlab
% Paul Garrett, 2024-08-05 4:02PM. CC4-Share-Share-Alike.
% - Data is randomly made and plotted
% - gca and gcf are used for axis and figure handling
% - latex interpreter used for plot text (Paul's aesthetic addition)
% - figure display on/off is used as a toggle
% - save function includes DPI for higher resolution images, and a size
% function to save the image in centimeters.
%
% In the email, I've also included a subplot tight function that allows you
% to cut white space from around the image - something I found really
% useful in my PhD/Honors.

% Make some random rt and acc data by 4 conditions...
cndtrials = 100;
cnds = 4;
cnd = reshape( repmat(1:cnds, cndtrials, 1), [], 1);
rt = rand(cndtrials*cnds, 1) * 1000;
acc = rand(cndtrials*cnds,1) < .75;
% Make error rts slower
rt(acc == 0) = rt(acc == 0) + rand(length(rt(acc == 0)),1) * 500;
% Round rts to the nearext ms
rt = round(rt);

% I like to have a display figure toggle so that if I need to regenerate
% images I can do it in the background 
DisplayFigure = true;
figure(1);

% Handle instances when you don't want to show a plot e.g., when you just
% want to save it to a file. Also, set the background to white.
if ~DisplayFigure
    set(gcf, 'visible','off', 'color','w');
else
    % If you want to show it as full screen size.
    set(gcf, 'Position', get(0, 'Screensize'), 'color','w');
end

% To update a plot in a loop, I need to prevent the canvas from being
% overwritten on each loop iteration; so I'll put a hold on displaying all 
% elements until the end. This only works because I've already declared the
% current figure via set(gcf...)
hold all;

% Make a plot
markersize = 100;
for ii = 1:cnds
    scatter(ii, mean(rt(acc == 1 & cnd == ii)), ... 
        markersize, 'green','filled','o','MarkerFaceAlpha', .25);
    scatter(ii, mean(rt(acc == 0 & cnd == ii)), markersize, 'red','filled','square');
end

% Set the axes to a line width of 1 with bold 12pt txt, no outside box and
% with LaTeX text (so it looks nice). You can make this helvetica or times
% etc; just look up options for Matlab text interpreters.
%
% NOTE: Get current axis 'gca' vs get current figure 'gcf'. These are great
% when you want to make flexible code with reference to whatever figure is
% currently being plotted.
set(gca, 'linewidth', 1,'fontweight','bold','fontsize',12, 'box','off','TickLabelInterpreter','LaTeX');

% Using LaTeX script language, make a main, x-axis, and y-axis title that 
% is bold font (\bf), size 14/16.
ylabel('\bf RT ($ms$)', 'FontWeight', 'bold', 'FontSize', 14,'Interpreter', 'LaTeX');
xlabel('\bf Conditions', 'FontWeight', 'bold', 'FontSize', 14,'Interpreter', 'LaTeX');
title('\bf My Title', 'FontWeight', 'bold', 'FontSize', 16,'Interpreter', 'LaTeX' );

% Set some sensible x and y bounds/limits
xlim([0.75, 4.25]);
ylim([0, 1000]);

% Set some sensible y and x label values to display.
yticks([0 250 500 750, 1000]);
xticks([1 2 3 4]);

% And make the X ticks actually describe the conditions
xticklabels({'A High', 'A Low', 'B High', 'B Low'});

% Note, if you're using subplots, then you'll need to modify
% the axis labels, ticks, and gca properties within the subplot loop
% otherwise it will only apply to the last subplot called (from memory).


% Set the size of the figure in centimeters to be 40 cm across and 20 cm
% high (I think this was my default but you can set this however you like.
% Just check what it looks like when you drop the image into a word doc or
% latex doc).
% Paper Position is ['X offset', 'Y offset', Xsize, Ysize]
figureSizeX = 15; % in centimeters
figureSizeY = 10; % in centimeters
set(gcf,'PaperUnits','centimeters','PaperPosition',[0 0 figureSizeX  figureSizeY], ...
    'PaperSize', [figureSizeX  figureSizeY]);

% Save the 'printed screen' as your image. This lets you set the 'dots per
% inch' (dpi) of the image. Published images usually require at least
% 300dpi or greater. This is so they don't look terrible when they're
% scaled up or down; but I'd recommend at least r400 or more if using a png
% or jpeg format. If using a PDF, this doesn't matter as it is a vector
% image and is therefore scale invariant. That's why pdf images are
% prefered in writing software like latex where you can scale them on the
% fly. The only dpi consideration is that the higher the dpi, the larger
% the file size, and the more costly it is to a) store and b) display,
% especially if it's in a word document.

% Example pdf figure save
print( 'ExampleFigure1', '-dpdf', '-r300');

% Example png figure save
print( 'ExampleFigure2' , '-dpng', '-r400');

% Close the figure and free up space.
close(gcf);