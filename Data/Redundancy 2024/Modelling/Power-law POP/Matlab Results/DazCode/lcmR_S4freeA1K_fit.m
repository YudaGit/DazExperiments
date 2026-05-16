% Clear workspace, close figures, and clear command window
clear;
close all;
clc;

%dataL = readtable('dataL.csv'); % Large N data
dataS = readtable('dataS.csv'); % Small N data

% Extract data
% data_PGexp1 = dataL(strcmp(dataL.uid, 'PGexp1'), :);
% data_YLexp1 = dataL(strcmp(dataL.uid, 'YLexp1'), :);

data_PGS = dataS(strcmp(dataS.uid, 'PG'), :);
data_YLS = dataS(strcmp(dataS.uid, 'YL'), :);
data_HCS = dataS(strcmp(dataS.uid, 'HC'), :);
data_AQS = dataS(strcmp(dataS.uid, 'AQ'), :);

% Define factors for standard conditions where setNum = colorNum
%set_Size = [2, 4, 6];
%color_Num = [2, 4, 6];
redun = {'Redundant Cued', 'Non-Redundant Cued'};

% Initialize a cell array to hold erRad values for all conditions
erRad_matrix = cell(9, 1);

% Extract PG data
erRad_matrix{1} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{2}) & ...
                                             data_PGS.setNum == 2 & ...
                                             data_PGS.colorNum == 2);
erRad_matrix{2} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{2}) & ...
                                             data_PGS.setNum == 4 & ...
                                             data_PGS.colorNum == 4);
erRad_matrix{3} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{2}) & ...
                                             data_PGS.setNum == 6 & ...
                                             data_PGS.colorNum == 6);
erRad_matrix{4} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{1}) & ...
                                             data_PGS.setNum == 4 & ...
                                             data_PGS.colorNum == 2);
erRad_matrix{5} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{2}) & ...
                                             data_PGS.setNum == 4 & ...
                                             data_PGS.colorNum == 2);
erRad_matrix{6} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{1}) & ...
                                             data_PGS.setNum == 6 & ...
                                             data_PGS.colorNum == 2);
erRad_matrix{7} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{2}) & ...
                                             data_PGS.setNum == 6 & ...
                                             data_PGS.colorNum == 2);
erRad_matrix{8} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{1}) & ...
                                             data_PGS.setNum == 6 & ...
                                             data_PGS.colorNum == 4);
erRad_matrix{9} = data_PGS.erRad(strcmp(data_PGS.redundancy, redun{2}) & ...
                                             data_PGS.setNum == 6 & ...
                                             data_PGS.colorNum == 4);
data_PGS = erRad_matrix;

% Extract YL data
erRad_matrix{1} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{2}) & ...
                                             data_YLS.setNum == 2 & ...
                                             data_YLS.colorNum == 2);
erRad_matrix{2} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{2}) & ...
                                             data_YLS.setNum == 4 & ...
                                             data_YLS.colorNum == 4);
erRad_matrix{3} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{2}) & ...
                                             data_YLS.setNum == 6 & ...
                                             data_YLS.colorNum == 6);
erRad_matrix{4} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{1}) & ...
                                             data_YLS.setNum == 4 & ...
                                             data_YLS.colorNum == 2);
erRad_matrix{5} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{2}) & ...
                                             data_YLS.setNum == 4 & ...
                                             data_YLS.colorNum == 2);
erRad_matrix{6} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{1}) & ...
                                             data_YLS.setNum == 6 & ...
                                             data_YLS.colorNum == 2);
erRad_matrix{7} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{2}) & ...
                                             data_YLS.setNum == 6 & ...
                                             data_YLS.colorNum == 2);
erRad_matrix{8} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{1}) & ...
                                             data_YLS.setNum == 6 & ...
                                             data_YLS.colorNum == 4);
erRad_matrix{9} = data_YLS.erRad(strcmp(data_YLS.redundancy, redun{2}) & ...
                                             data_YLS.setNum == 6 & ...
                                             data_YLS.colorNum == 4);

data_YLS = erRad_matrix;

% Extract HC data
erRad_matrix{1} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{2}) & ...
                                             data_HCS.setNum == 2 & ...
                                             data_HCS.colorNum == 2);
erRad_matrix{2} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{2}) & ...
                                             data_HCS.setNum == 4 & ...
                                             data_HCS.colorNum == 4);
erRad_matrix{3} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{2}) & ...
                                             data_HCS.setNum == 6 & ...
                                             data_HCS.colorNum == 6);
erRad_matrix{4} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{1}) & ...
                                             data_HCS.setNum == 4 & ...
                                             data_HCS.colorNum == 2);
erRad_matrix{5} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{2}) & ...
                                             data_HCS.setNum == 4 & ...
                                             data_HCS.colorNum == 2);
erRad_matrix{6} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{1}) & ...
                                             data_HCS.setNum == 6 & ...
                                             data_HCS.colorNum == 2);
erRad_matrix{7} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{2}) & ...
                                             data_HCS.setNum == 6 & ...
                                             data_HCS.colorNum == 2);
erRad_matrix{8} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{1}) & ...
                                             data_HCS.setNum == 6 & ...
                                             data_HCS.colorNum == 4);
erRad_matrix{9} = data_HCS.erRad(strcmp(data_HCS.redundancy, redun{2}) & ...
                                             data_HCS.setNum == 6 & ...
                                             data_HCS.colorNum == 4);

data_HCS = erRad_matrix;

% Extract AQ data
erRad_matrix{1} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{2}) & ...
                                             data_AQS.setNum == 2 & ...
                                             data_AQS.colorNum == 2);
erRad_matrix{2} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{2}) & ...
                                             data_AQS.setNum == 4 & ...
                                             data_AQS.colorNum == 4);
erRad_matrix{3} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{2}) & ...
                                             data_AQS.setNum == 6 & ...
                                             data_AQS.colorNum == 6);
erRad_matrix{4} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{1}) & ...
                                             data_AQS.setNum == 4 & ...
                                             data_AQS.colorNum == 2);
erRad_matrix{5} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{2}) & ...
                                             data_AQS.setNum == 4 & ...
                                             data_AQS.colorNum == 2);
erRad_matrix{6} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{1}) & ...
                                             data_AQS.setNum == 6 & ...
                                             data_AQS.colorNum == 2);
erRad_matrix{7} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{2}) & ...
                                             data_AQS.setNum == 6 & ...
                                             data_AQS.colorNum == 2);
erRad_matrix{8} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{1}) & ...
                                             data_AQS.setNum == 6 & ...
                                             data_AQS.colorNum == 4);
erRad_matrix{9} = data_AQS.erRad(strcmp(data_AQS.redundancy, redun{2}) & ...
                                             data_AQS.setNum == 6 & ...
                                             data_AQS.colorNum == 4);

data_AQS = erRad_matrix;

%% can also do with table that has headings
% Can make a function that takes the conditions, data, and table
% Matlab function is a separate file, recent matlab allow function at the end of script
% clearvars -except data_PGS
% x.data = data_HCS this is how to do structures, so I have clean
% workspace, and can get them back later
%% Initialize parameters and selection switch
initial_guess =   [1, 1, 1, 1, 1, 1, 1, 1, 1, 2];  % Initial guess for 9 a's and 1 kappa
fixed = [];
Sel =             [1, 1, 1, 1, 1, 1, 1, 1, 1, 1];  % Selection switch (all parameters are free)
set_Size = [2, 4, 6, 4, 4, 6, 6, 6, 6];  % Conditions

% Set fminsearch options
options = optimset('Display', 'iter', ...
                   'TolX', 1e-6, ...
                   'TolFun', 1e-6, ...
                   'MaxIter', 1000, ...
                   'MaxFunEvals', 10000);

% Fit the model for all conditions using fminsearch
[estimated_params, fval, exitflag, output] = fminsearch(@(Pvar) ...
    lcmR_S4freeA1K(Pvar, fixed, Sel, data_AQS, set_Size), ...
    initial_guess(Sel==1), options);

% Extract AIC and BIC from the model using the estimated parameters
[~, aic, bic] = lcmR_S4freeA1K(estimated_params, [], Sel, data_AQS, set_Size);

% Display the results with four decimal places
fprintf('Estimated Parameters: a = %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f\n kappa = %.4f\n', ...
    estimated_params(1:9), estimated_params(10));
fprintf('LogLikelihood: %.4f\n', fval);
fprintf('AIC: %.4f\n', aic);
fprintf('BIC: %.4f\n', bic);
fprintf('Exit flag: %d\n', exitflag);
disp('Output details:');
disp(output);

% Store the results in a table
results = table(set_Size', estimated_params(1:9)', repmat(estimated_params(10), 9, 1), repmat(fval, 9, 1), repmat(aic, 9, 1), repmat(bic, 9, 1), ...
                'VariableNames', {'SetSize', 'a', 'Kappa', 'LogLikelihood', 'AIC', 'BIC'});

% Display the final results table
disp('Final Results:');
disp(results);


%% Plotting
% Extract the estimated a and kappa parameters
a2_est = estimated_params(1:9);
kappa_est = estimated_params(10);

% Define the number of detectors
n = 360;

% Define the bin edges for consistent bin widths
num_bins = 120; % Number of bins
bin_edges = linspace(-pi, pi, num_bins + 1); % Define bin edges for 120 bins

% Create a figure to hold the subplots
figure;

% Loop through each condition
for i = 1:length(set_Size)
    % Get the data for the current condition
    if ~isempty(data_AQS{i}) && isnumeric(data_AQS{i})
        data = data_AQS{i};
        
        % Calculate the predicted tuning function
        amplitude = a2_est(i); % Use the estimated amplitude for each set size
        [theta, ptheta] = guplcm([amplitude, kappa_est], n);
        
        % Estimate the PDF from the data
        [f, xi] = ksdensity(data, 'Bandwidth', 0.1, 'Function', 'pdf');
        
        % Plot the histogram of the data with consistent bin widths
        subplot(3, 3, i); % Adjust the subplot layout to 3x3
        histogram(data, 'Normalization', 'pdf', 'BinEdges', bin_edges, 'FaceColor', [0.8, 0.8, 0.8]);
        hold on;
        
        % Plot the estimated data PDF
        plot(xi, f, 'c-', 'LineWidth', 2);
        
        % Plot the predicted tuning function
        plot(theta, ptheta, 'k--', 'LineWidth', 2);
        
        % Set plot labels and title
        xlabel('Error (radians)');
        ylabel('Density');
        title(sprintf('Set Size %d', set_Size(i)));
        legend('Data Histogram', 'Data PDF', 'Model PDF');
        hold off;
    else
        warning('Data for Set Size %d is empty or invalid.', set_Size(i));
    end
end

%%
% Extract the amplitude estimates and set sizes
amplitudes = results.a;
setSizes = results.SetSize;

% Define beta (assume the beta you want to use for theoretical prediction)
beta = 0.5;

% Calculate the base amplitude (hypothetical set size 1)
baseAmp = amplitudes(1) * sqrt(2);

% Calculate the theoretical predictions based on the base amplitude and beta
theoretical_predictions = baseAmp .* (setSizes.^-beta);

% Combine the base amplitude and theoretical predictions for plotting
all_amplitudes = [baseAmp; theoretical_predictions];
all_set_sizes = [1; setSizes];

% Create the plot
figure;
hold on;

% Plot the amplitude estimates
scatter(setSizes, amplitudes, 100, 'filled', 'c'); % 'SizeData' is for plot, 100 is the marker size

% Plot the theoretical predictions and base amplitude in grey with a dashed line
plot(all_set_sizes, all_amplitudes, 'k--', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 2);
scatter(1, baseAmp, 100, 'filled', 'k', 'MarkerFaceColor', [0.5, 0.5, 0.5]); % 'SizeData' is for scatter, 100 is the marker size

% Set plot labels and title
xlabel('Set Size', 'FontSize', 12);
ylabel('Amplitude (a)', 'FontSize', 12);
title('Amp est vs Sample-Size Predictions', 'FontSize', 12);

% Add legend
legend('Estimated Amplitudes', 'Theoretical Predictions and Base Amplitude', 'Location', 'Best', 'FontSize', 14);

% Set x-axis limits to cover the range of set sizes
xlim([0, max(setSizes) + 1]);

% Set y-axis limits to provide a clear view of the data
ylim([0, max([amplitudes; theoretical_predictions; baseAmp]) * 1.1]);

% Add grid for better readability
grid on;

% Tag each amplitude dot with the specified labels
labels = {'2/2', '4/4', '6/6', '4/2R', '4/2N', '6/2R', '6/2N', '6/4R', '6/4N'};
for i = 1:length(amplitudes)
    text(setSizes(i), amplitudes(i), labels{i}, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', 'FontSize', 16);
end

hold off;


% Ensure the guplcm function is at the end of the file
function [theta, ptheta] = guplcm(P, n)
    a = P(1);
    kappa = P(2);
    theta = linspace(-pi, pi, n); % will wrap around
    utheta = a * exp(kappa * cos(theta)) / (2 * pi); % Tuning function
    ptheta = exp(utheta) / sum(exp(utheta));
    h = theta(2) - theta(1);
    ptheta = ptheta / h;
end
