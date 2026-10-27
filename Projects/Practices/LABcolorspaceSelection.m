


v.incriments = 360 * 3;

% What Zhang and Luck 1997 used
v.ZhangLuck.L = 70;
v.ZhangLuck.a = 20;
v.ZhangLuck.b = 38;
v.ZhangLuck.radius = 60; % was 60.

% What Paul used in his DECRA application
v.paul.L = 65;
v.paul.a = 20;
v.paul.b = 0;
v.paul.radius = 67;

% Modified Colors
v.color.L = 65;
v.color.a = 20;
v.color.b = 0;
v.color.radius = 70;

% What Adam et al 2017 used 
% "...centered at L = 54, a = 18, b = −8; Wyszecki & Stiles, 1982"
v.adam.L = 54;      % was 54, looks too dark
v.adam.a = 18;
v.adam.b = -8;
v.adam.radius = 60; % was 60, looks too dark

showColorWheel = false;

if showColorWheel
    subplot(2,2,1);
    makeColorMap(v.color.L, v.color.a, v.color.b, v.color.radius, v.incriments);
    title('Modified colors')
    
    subplot(2,2,2);
    makeColorMap(v.ZhangLuck.L, v.ZhangLuck.a, v.ZhangLuck.b, v.ZhangLuck.radius, v.incriments);
    title('Zhang Luck colors')
    
    subplot(2,2,3);
    makeColorMap(v.adam.L, v.adam.a, v.adam.b, v.adam.radius, v.incriments);
    title('Adam 2017 colors')
    
    subplot(2,2,4);
    makeColorMap(v.paul.L, v.paul.a, v.paul.b, v.paul.radius, v.incriments);
    title('Paul DECRA colors')

end

OKl = linspace(.85, .8, 4);
OKr = linspace(.20, .23, 4);

c = 1;
for L = OKl
    for r = OKr
        subplot_tight(4, 4, c, [.07, .07]);
        DrawOKLabWheel(L, r, 360);
        c = c + 1;
    end
end

% Suggested values in OK lab: L=.83 and r=.21

function [colorMap, anglesMap] = makeColorMap(L, a, b, radius, incriments)
    
    color.angles = 0:2*pi/incriments:2*pi;
    color.map(:,2:3) = radius*[cos(color.angles') sin(color.angles')];
    color.map(:,1) = L;
    color.map(:,2) = color.map(:,2) + a;
    color.map(:,3) = color.map(:,3) + b;
    color.map(end,:) = [];
    color.angles = color.angles(1:end-1);
    labmap = color.map;

    cform = makecform('lab2srgb');
    colorMap = applycform(color.map, cform) * 255;
    anglesMap = color.angles;

    DrawWheelFigure(colorMap, anglesMap)
    
end


function DrawWheelFigure(colorMap, angles)
    annulus.radiusInner = 30;
    annulus.radiusOuter = 60;
    % Create a new figure and set background color
    hold all;
    axis equal;  % Keep axes from distorting circles

    % Draw the color wheel lines
    for ii = 1:length(angles)
        xStart = annulus.radiusInner * cos(angles(ii));
        yStart = annulus.radiusInner * sin(angles(ii));
        xEnd = annulus.radiusOuter * cos(angles(ii));
        yEnd = annulus.radiusOuter * sin(angles(ii));

        % Draw each line
        line([xStart, xEnd], [yStart, yEnd], ...
             'LineWidth', 2, ...
             'Color', colorMap(ii, :)/255);
    end

    hold off;
end




function DrawOKLabWheel(L_ok, radius, nSteps, annulusRadii)
% DrawOKLabWheel  Display an OK-Lab colour wheel
%
%   DrawOKLabWheel()                 % default wheel
%   DrawOKLabWheel(L_ok, radius)     % custom lightness / chroma
%   DrawOKLabWheel(L_ok, radius, n)  % + number of spokes
%   DrawOKLabWheel(L_ok, r, n, [ri ro]) % + inner/outer radii (px)

% ---------- defaults -----------------------------------------------------
if nargin < 1 || isempty(L_ok),      L_ok       = 0.80;    end   % 0–1
if nargin < 2 || isempty(radius),    radius     = 0.20;    end   % 0–0.4 ish
if nargin < 3 || isempty(nSteps),    nSteps     = 360*3;   end   % 0.33° steps
if nargin < 4 || isempty(annulusRadii), annulusRadii = [30 60]; end
ri = annulusRadii(1);  ro = annulusRadii(2);

% ---------- OK-Lab circle ------------------------------------------------
theta = linspace(0,2*pi,nSteps+1).';   % +duplicate 0/2π
theta(end) = [];                       % remove duplicate
a_ok = radius.*cos(theta);
b_ok = radius.*sin(theta);
okLab = [repmat(L_ok,numel(theta),1), a_ok, b_ok];

% ---------- OK-Lab → linear sRGB ----------------------------------------
rgbLin = okLab2linSRGB(okLab);         % (0–1, may be outside gamut)

% ---------- linear → display sRGB, clip to gamut ------------------------
rgb = lin2srgb(rgbLin);
rgb = max(min(rgb,1),0);               % hard clip out-of-gamut

% ---------- plot ---------------------------------------------------------
set(gcf, 'Color',[1 1 1]);  hold on;  axis equal off
for k = 1:numel(theta)
    xs = ri*cos(theta(k));  ys = ri*sin(theta(k));
    xe = ro*cos(theta(k));  ye = ro*sin(theta(k));
    line([xs xe],[ys ye],'LineWidth',2,'Color',rgb(k,:));
end
title(sprintf('L=%.2f, r=%.2f',L_ok,radius));
end
% ========================================================================
function srgb = lin2srgb(linRGB)
% Linear sRGB (0–1) → display sRGB (0–1)
th = 0.0031308;
srgb = zeros(size(linRGB));
lo   = linRGB <= th;
srgb(lo)  = 12.92*linRGB(lo);
srgb(~lo) = 1.055*linRGB(~lo).^(1/2.4) - 0.055;
end
% ------------------------------------------------------------------------
function linRGB = okLab2linSRGB(okLab)
% OK-Lab → linear sRGB (Oksanen, 2020)

L = okLab(:,1);  a = okLab(:,2);  b = okLab(:,3);

l_ = L + 0.3963377774*a + 0.2158037573*b;
m_ = L - 0.1055613458*a - 0.0638541728*b;
s_ = L - 0.0894841775*a - 1.2914855480*b;

LMS = [l_.^3, m_.^3, s_.^3];          % undo cube-root

M = [ ...
     4.0767416621  -3.3077115913   0.2309699292 ; ...
    -1.2684380046   2.6097574011  -0.3413193965 ; ...
    -0.0041960863  -0.7034186147   1.7076147010 ];
linRGB = LMS * M.';                   % to linear sRGB
end
