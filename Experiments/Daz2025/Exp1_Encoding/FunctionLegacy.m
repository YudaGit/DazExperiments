% ─────────────────────────── Inter-trial feedback ────────────────────────────
function DrawIntertrialFeedback(trials, ii, display)
% PTB-only feedback: Easy / Medium / Hard   (v2)
if nargin<3, display = true; end
global V

%  data & category ------------------------------------------------
errDeg = abs(trials.Precision);                  % 0 = perfect, 180 = worst
dur     = trials.PresDur;                        % presentation duration (s)

% difficulty bins
cat = strings(size(dur));
cat(ismember(dur,[0.30 0.35])) = "Easy";
cat(ismember(dur,[0.15 0.20 0.25])) = "Medium";
cat(ismember(dur,[0.05 0.10])) = "Hard";
cats = ["Easy","Medium","Hard"];                 % display order

% colour map keyed by duration (×100 → integer)
rgb = @(r,g,b)[r g b]/255;
colMap = containers.Map( ...
   {'50','100','150','200','250','300','350'},...
   {rgb(255, 90, 60), rgb(220, 40, 30), ...             % 50 100  (Hard)
    rgb( 20,160,180), rgb( 29,128,255), rgb( 99,195,255),... % 150-250 (Medium)
    rgb( 23,170, 23), rgb( 56,200, 56)});               % 300 350 (Easy)

%  geometry -------------------------------------------------------
[winW,winH] = Screen('WindowSize',V.window);
panelH   = 0.60*winH;           % 60 % height  (equal for all)
panelY0  = 0.25*winH;           % common bottom
barW     = 2;                   % bar width  px
gapW     = 2;                   % gap width  px
pitch    = barW + gapW;         % 4 px
yScale   = panelH/180;          % 180 deg → full panel height

panelW   = [0.26 0.48 0.26]*winW;   % Easy | Medium | Hard
panelX0  = [0.02 0.27 0.75]*winW;   % left edges

% clear screen ---------------------------------------------------
Screen('FillRect',V.window,[V.patch.bg V.patch.bg V.patch.bg]);

%  draw each panel -----------------------------------------------
Screen('TextFont',V.window,'Helvetica');
for p = 1:3
    idx = cat==cats(p);
    n   = sum(idx);
    if n==0, continue, end

    xLeft = panelX0(p) + gapW;                    % first bar left edge
    yBase = panelY0 + panelH;                     % bottom

    % allocate rectangles & colours
    rects  = zeros(4,n);
    colours= zeros(3,n);

    k = 0;
    for t = find(idx).'
        k = k+1;
        height = (180-errDeg(t))*yScale;
        left   = xLeft + (k-1)*pitch;
        rects(:,k) = [left; yBase-height; left+barW; yBase];

        key = num2str(round(dur(t)*1000));         % e.g. 150
        colours(:,k) = colMap(key).';
    end
    Screen('FillRect',V.window,colours,rects);

    % frame & ticks
    box = [panelX0(p) panelY0 panelX0(p)+panelW(p) panelY0+panelH];
    Screen('FrameRect',V.window,[180 180 180],box,1);

    % horizontal ticks every 30°
    for yTick = 0:30:180
        y = yBase - yTick*yScale;
        Screen('DrawLine',V.window,[180 180 180],box(1),y,box(3),y,1);
    end

    % title
    Screen('TextSize',V.window,24);
    DrawFormattedText(V.window,upper(char(cats(p))),'center',...
        panelY0-35,[255 255 255],[],[],[],[],[],box);
end

%header & footer -------------------------------------------------
Screen('TextSize',V.window,48);
DrawFormattedText(V.window,...
    sprintf('Completed Trial %d of %d',ii,size(trials,1)),...
    'center',winH*0.08,[255 255 255]);

Screen('TextSize',V.window,32);
DrawFormattedText(V.window,...
    'Click the left mouse button to continue',...
    'center',winH*0.90,[255 255 255]);

% show & wait -----------------------------------------------------
Screen('Flip',V.window);
if display, WaitForMouseClick; end
end

%────────────────────────────────────────────────────────────────────────
function fbBuffer = InitFeedbackBuffer(nTrials, plotHeight, presDurList)
    % Initialize an RGB image buffer for the full plot
    totalWidth = nTrials * 4;  % 2px bar + 2px spacing per trial
    fbBuffer.img = uint8(ones(plotHeight, totalWidth, 3) * 255);  % white background
    fbBuffer.currentTrial = 0;
    fbBuffer.plotHeight = plotHeight;
    fbBuffer.presDurList = sort(unique(presDurList));  % e.g. [0.05 0.10 ... 0.35]
    fbBuffer.colors = colormapPresDur(length(fbBuffer.presDurList));
end

%────────────────────────────────────────────────────────────────────────
function img = UpdateFeedbackBuffer(fbBuffer, precisionDeg, presDur)
    % precisionDeg = absolute angular error (0 = perfect, 180 = worst)
    % presDur = presentation duration in seconds

    fbBuffer.currentTrial = fbBuffer.currentTrial + 1;

    % Inverse precision (smaller = better)
    maxPrecision = 90;  % can be tuned
    barHeight = round((1 - min(precisionDeg / maxPrecision, 1)) * fbBuffer.plotHeight);

    % Determine x-pixel start
    xStart = (fbBuffer.currentTrial - 1) * 4 + 1;
    xRange = xStart : xStart+1;

    % Color by presDur
    presIdx = find(fbBuffer.presDurList == presDur);
    if isempty(presIdx)
        barColor = [0 0 0];
    else
        barColor = fbBuffer.colors(presIdx,:);
    end
    
    % Draw bar
    fbBuffer.img(end-barHeight+1:end, xRange, 1) = barColor(1);
    fbBuffer.img(end-barHeight+1:end, xRange, 2) = barColor(2);
    fbBuffer.img(end-barHeight+1:end, xRange, 3) = barColor(3);

    img = fbBuffer.img;
end

%────────────────────────────────────────────────────────────────────────
function cmap = colormapPresDur(n)
    cmap = [linspace(0.5, 0.0, n)', linspace(0.5, 1.0, n)', linspace(0.5, 0.0, n)'];
    cmap = uint8(cmap * 255);
end

% Example use inside trial loop:
% if ii == 1
%     fb = InitFeedbackBuffer(nTrials, 300, expTrials.PresDur);
% end
% plotImg = UpdateFeedbackBuffer(fb, expTrials.Precision(ii), expTrials.PresDur(ii));
% tex = Screen('MakeTexture', winPtr, plotImg);
% DisplayFeedbackTexture(tex, winPtr, winRect, ii, nTrials);
% Screen('Close', tex);


%%Previous working version

% ─────────────────────────── Inter-trial feedback ────────────────────────────
function tex = GenerateFeedbackTexture(trialsSoFar, winPtr, totalTrialN)
    % Compute precision score: 0–10 scale
    precisionDeg = abs(trialsSoFar.Precision);
    precisionScore = 10 * (1 - precisionDeg / 180);
    precisionScore = max(0, min(10, precisionScore));  % clip just in case

    % PresDur to color mapping (7 levels)
    presDurLevels = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35];
    colorMap = [...
        0.7, 0.0, 0.0;   % dark red
        0.8, 0.3, 0.0;
        0.9, 0.6, 0.1;
        0.6, 0.7, 0.2;
        0.4, 0.8, 0.2;
        0.3, 0.9, 0.4;
        0.2, 1.0, 0.6];  % light green

    % Match color to PresDur
    idx = arrayfun(@(x) find(presDurLevels == x, 1), trialsSoFar.PresDur);
    trialColors = colorMap(idx, :);

    % === Canvas settings ===
    barWidth = 2;
    spacing = 2;
    numTrials = totalTrialN;
    numSoFar = height(trialsSoFar);

    canvasWidthPx = numTrials * (barWidth + spacing);
    canvasHeightPx = 300;
    dpi = 100;
    figW = canvasWidthPx / dpi;
    figH = canvasHeightPx / dpi;

    fig = figure('Visible', 'off', 'Color', 'w', ...
                 'Units', 'inches', 'Position', [1, 1, figW, figH]);

    ax = axes('Position', [0.05, 0.2, 0.93, 0.7]);
    xlim([0, numTrials * (barWidth + spacing)]);
    ylim([0 10]);
    hold on;

    % Plot completed trials
    for i = 1:numSoFar
        xPos = (i - 1) * (barWidth + spacing);
        h = precisionScore(i);
        c = trialColors(i, :);
        rectangle('Position', [xPos, 0, barWidth, h], ...
                  'FaceColor', c, 'EdgeColor', 'none');
    end

    % Plot empty gray bars for future trials
    for i = (numSoFar+1):numTrials
        xPos = (i - 1) * (barWidth + spacing);
        rectangle('Position', [xPos, 0, barWidth, 0.2], ...
                  'FaceColor', [0.85, 0.85, 0.85], 'EdgeColor', 'none');
    end

    % Axes formatting
    ylabel('Precision Score', 'FontWeight', 'bold', 'FontSize', 12);
    set(ax, 'YTick', 0:2:10, 'XTick', [], 'Box', 'off', 'FontSize', 10);

    drawnow;
    frame = getframe(fig);
    img = frame2im(frame);
    close(fig);

    tex = Screen('MakeTexture', winPtr, img);
end

function DisplayFeedbackTexture(tex, winPtr, winRect, trialNum, totalTrials)
    Screen('FillRect', winPtr, [128 128 128]);  % background
    texSize = Screen('Rect', tex);
    dstRect = CenterRectOnPoint(texSize * 1.25, winRect(3)/2, winRect(4)/2);
    
    Screen('DrawTexture', winPtr, tex, [], dstRect);

    % Trial info text
    Screen('TextSize', winPtr, 36);
    DrawFormattedText(winPtr, ...
        sprintf('Completed Trial %d of %d', trialNum, totalTrials), ...
        'center', winRect(4)*0.08, [255 255 255]);
    DrawFormattedText(winPtr, ...
        'Click to continue', ...
        'center', winRect(4)*0.95, [255 255 255]);

    Screen('Flip', winPtr);
    WaitForMouseClick();  % your helper function
end


