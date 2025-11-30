% Test if pickUniqueHues is truly random or has bias
% Run multiple times to check distribution

clear; close all;

% Add path if needed
addpath(genpath(pwd));

% Initialize minimal V structure
global V
V.color.rotation = randi([0, 359]);

% Test parameters
nTrials = 1000;
nHues = 4;  % Test with 4 hues (like N=4 baseline)
mindeg = 30;

% Collect all first hues (to check if there's bias in starting point)
firstHues = [];
allHues = [];

fprintf('Testing pickUniqueHues randomness...\n');
fprintf('Running %d trials with %d hues each (min spacing: %d°)\n\n', nTrials, nHues, mindeg);

for t = 1:nTrials
    hues = pickUniqueHues(nHues, mindeg, []);
    firstHues(end+1) = hues(1);
    allHues = [allHues, hues];
end

% Check distribution of first hues
figure;
subplot(2,2,1);
histogram(firstHues, 0:30:360);
xlabel('First Hue (degrees)');
ylabel('Frequency');
title('Distribution of First Hue');
grid on;

% Check distribution of all hues
subplot(2,2,2);
histogram(allHues, 0:30:360);
xlabel('All Hues (degrees)');
ylabel('Frequency');
title('Distribution of All Hues');
grid on;

% Kolmogorov-Smirnov test for uniform distribution
[h1, p1] = kstest(firstHues / 360);
[h2, p2] = kstest(allHues / 360);

fprintf('First hue distribution:\n');
fprintf('  Kolmogorov-Smirnov test: p = %.4f\n', p1);
if p1 > 0.05
    fprintf('  ✓ First hues appear uniformly distributed\n');
else
    fprintf('  ✗ First hues may not be uniformly distributed (p = %.4f)\n', p1);
end

fprintf('\nAll hues distribution:\n');
fprintf('  Kolmogorov-Smirnov test: p = %.4f\n', p2);
if p2 > 0.05
    fprintf('  ✓ All hues appear uniformly distributed\n');
else
    fprintf('  ✗ All hues may not be uniformly distributed (p = %.4f)\n', p2);
end

% Check if there are any "dead zones" (hues that are never selected)
hueBins = 0:30:360;
binCounts = histcounts(allHues, hueBins);
subplot(2,2,3);
bar(binCounts);
xlabel('Hue Bin (degrees)');
ylabel('Frequency');
title('Hue Distribution by 30° Bins');
xticklabels(0:30:330);
grid on;

% Check minimum spacing
minDists = [];
for t = 1:nTrials
    hues = pickUniqueHues(nHues, mindeg, []);
    minDist = 360;
    for i = 1:length(hues)
        for j = i+1:length(hues)
            dist = min(abs(hues(i)-hues(j)), 360-abs(hues(i)-hues(j)));
            minDist = min(minDist, dist);
        end
    end
    minDists(end+1) = minDist;
end

subplot(2,2,4);
histogram(minDists, 0:5:180);
xlabel('Minimum Distance (degrees)');
ylabel('Frequency');
title('Distribution of Minimum Distances');
xline(mindeg, 'r--', 'LineWidth', 2, 'DisplayName', sprintf('%d° threshold', mindeg));
legend('Distances', sprintf('%d° threshold', mindeg));
grid on;

fprintf('\nMinimum spacing check:\n');
fprintf('  All trials have min distance >= %d°: %s\n', mindeg, ...
    char(string(all(minDists >= mindeg))));
fprintf('  Mean minimum distance: %.1f°\n', mean(minDists));
fprintf('  Median minimum distance: %.1f°\n', median(minDists));

fprintf('\nTest complete!\n');

