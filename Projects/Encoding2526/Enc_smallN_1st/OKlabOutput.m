% OKLab palette export (stand‑alone, no PTB needed)
clear; clc;

L = 0.85;
radius = 0.23;
n = 360;

angles = 0 : (2*pi/n) : (2*pi - 2*pi/n);   % 360 samples
a = radius * cos(angles);
b = radius * sin(angles);

% OKLab -> linear sRGB
l_ = L + 0.3963377774 .* a + 0.2158037573 .* b;
m_ = L - 0.1055613458 .* a - 0.0638541728 .* b;
s_ = L - 0.0894841775 .* a - 1.2914855480 .* b;

LMS = [l_.^3; m_.^3; s_.^3]';

M = [ 4.0767416621, -3.3077115913,  0.2309699292;
     -1.2684380046,  2.6097574011, -0.3413193965;
     -0.0041960863, -0.7034186147,  1.7076147010];

rgbLin = LMS * M.';
rgbLin = max(min(rgbLin,1),0);   % clip

% linear sRGB -> gamma sRGB
srgb = zeros(size(rgbLin));
mask = rgbLin <= 0.0031308;
srgb(mask) = 12.92 * rgbLin(mask);
srgb(~mask) = 1.055 * rgbLin(~mask).^(1/2.4) - 0.055;

rgb255 = srgb * 255;

idx = (0:n-1)';
T = table(idx, rgb255(:,1), rgb255(:,2), rgb255(:,3), ...
          'VariableNames', {'index','r','g','b'});

writetable(T, 'oklab_palette_matlab.csv');
disp('Wrote oklab_palette_matlab.csv');