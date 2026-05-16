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
% initial_guess =   [1, 0.5, 0.5, 0.5, 3];  % Initial guess for a2, beta1, beta2, beta3, kappa
% fixed = [];
% Sel =             [1, 1, 1, 1, 1];  % Selection switch (all parameters are free)
% set_Size = [2, 4, 6, 4, 4, 6, 6, 6, 6];  % Conditions
% 
% % Define lower and upper bounds for parameters
% lb = [1, 0.3, 0.3, 0.3, 2];  % Lower bounds
% ub = [10, 1, 1, 1, 10];           % Upper bounds
% 
% % Set fmincon options
% options = optimoptions('fmincon', ...
%                    'Display', 'iter', ...
%                    'Algorithm', 'sqp', ... % Use 'sqp' algorithm
%                    'TolX', 1e-6, ...
%                    'TolFun', 1e-6, ...
%                    'MaxIter', 1000, ...
%                    'MaxFunEvals', 10000);
% 
% % Fit the model for all conditions using fmincon
% [estimated_params, fval, exitflag, output] = fmincon(@(Pvar) ...
%     lcmR_S51A3B1K(Pvar, fixed, Sel, data_PGS, set_Size), ...
%     initial_guess(Sel==1), [], [], [], [], lb, ub, [], options);
% 
% % Extract AIC and BIC from the model using the estimated parameters
% [~, aic, bic] = lcmR_S51A3B1K(estimated_params, [], Sel, data_PGS, set_Size);
% 
% % Display the results with four decimal places
% fprintf(['Estimated Parameters: a2 = %.4f\n beta1 = %.4f\n beta2 = %.4f\n beta3 = %.4f\n' ...
%          'kappa = %.4f\n'], ...
%     estimated_params(1), estimated_params(2), estimated_params(3), estimated_params(4), estimated_params(5));
% fprintf('LogLikelihood: %.4f\n', fval);
% fprintf('AIC: %.4f\n', aic);
% fprintf('BIC: %.4f\n', bic);
% fprintf('Exit flag: %d\n', exitflag);
% disp('Output details:');
% disp(output);
% 
% % Create arrays to match amplitude and beta values to their corresponding conditions
% amplitude_values = repmat(estimated_params(1), 9, 1);  % a2 for all conditions
% beta_values = zeros(9, 1);  % Preallocate for beta values
% 
% % Assign beta values based on the condition groups
% beta_values([1, 2, 3]) = estimated_params(2);  % beta1 for conditions 1, 2, 3
% beta_values([4, 6, 8]) = estimated_params(3);  % beta2 for conditions 4, 6, 8
% beta_values([5, 7, 9]) = estimated_params(4);  % beta3 for conditions 5, 7, 9
% 
% % Store the results in a table
% results = table(set_Size', amplitude_values, beta_values, repmat(estimated_params(5), 9, 1), ...
%     repmat(fval, 9, 1), repmat(aic, 9, 1), repmat(bic, 9, 1), ...
%     'VariableNames', {'SetSize', 'Amplitude', 'Beta', 'Kappa', 'LogLikelihood', 'AIC', 'BIC'});
% 
% % Display the final results table
% disp('Final Results:');
% disp(results);

%% Fitting
% Initialize parameters and selection switch
initial_guess = [1, 0.5, 0.5, 2];  % Initial guess for a2, beta1, beta2, and kappa
fixed = [];
Sel = [1, 1, 1, 1];  % Selection switch (all parameters are free)
set_Size = [2, 4, 6, 4, 4, 6, 6, 6, 6];  % Conditions
colour_Num = [2, 4, 6, 2, 2, 2, 2, 4, 4]; % Number of colours

% Set fminsearch options
options = optimset('Display', 'iter', ...
                   'TolX', 1e-6, ...
                   'TolFun', 1e-6, ...
                   'MaxIter', 1000, ...
                   'MaxFunEvals', 10000);

% Fit the model for all conditions using fminsearch
[estimated_params, fval, exitflag, output] = fminsearch(@(Pvar) ...
    lcmR_S61A2B1K(Pvar, fixed, Sel, data_AQS, set_Size), ...
    initial_guess(Sel == 1), options);

% Extract AIC and BIC from the model using the estimated parameters
[~, aic, bic] = lcmR_S61A2B1K(estimated_params, [], Sel, data_AQS, set_Size);

% Display the results with four decimal places
fprintf(['Estimated Parameters: a2 = %.4f\n beta1 = %.4f\n beta2 = %.4f\n' ...
         'kappa = %.4f\n'], ...
    estimated_params(1), estimated_params(2), estimated_params(3), estimated_params(4));
fprintf('LogLikelihood: %.4f\n', fval);
fprintf('AIC: %.4f\n', aic);
fprintf('BIC: %.4f\n', bic);
fprintf('Exit flag: %d\n', exitflag);
disp('Output details:');
disp(output);

% Create arrays to match amplitude and beta values to their corresponding conditions
amplitude_values = zeros(size(set_Size));
beta_values = zeros(size(set_Size));
for i = 1:length(set_Size)
    if ismember(i, [1, 2, 3])
        beta_values(i) = 0.5;
        baseAmp = estimated_params(1) * 2 .^ beta_values(i);
        amplitude_values(i) = baseAmp * colour_Num(i) .^ -beta_values(i);
    elseif ismember(i, [4, 6, 8])
        beta_values(i) = estimated_params(2);
        baseAmp = estimated_params(1) * 2 .^ beta_values(i);
        redunAmp = baseAmp * ((set_Size(i) - (colour_Num(i) - 1)) .^ beta_values(i));
        amplitude_values(i) = redunAmp * (colour_Num(i) .^ -beta_values(i));
    else
        beta_values(i) = estimated_params(3);
        baseAmp = estimated_params(1) * 2 .^ beta_values(i);
        amplitude_values(i) = baseAmp * (colour_Num(i) .^ -beta_values(i));
    end
end

% Store the results in a table
results = table(set_Size', amplitude_values', beta_values', repmat(estimated_params(4), 9, 1), repmat(fval, 9, 1), repmat(aic, 9, 1), repmat(bic, 9, 1), ...
                'VariableNames', {'SetSize', 'Amplitude', 'Beta', 'Kappa', 'LogLikelihood', 'AIC', 'BIC'});

% Display the final results table
disp('Final Results:');
disp(results);


%% Plotting
% Extract the estimated parameters
a2_est = estimated_params(1);
beta1_est = estimated_params(2); % for Redundant Cue conditions
beta2_est = estimated_params(3); % for Non-redundant Cue conditions
kappa_est = estimated_params(4);

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
        if any(i == [1, 2, 3]) % Standard conditions
            amplitude = (a2_est * 2^0.5) / (colour_Num(i)^0.5);

        elseif any(i == [4, 6, 8]) % Redundant Cue conditions
            baseAmp = a2_est * 2^beta1_est;
            redunAmp = baseAmp * (set_Size(i) - (colour_Num(i) - 1))^beta1_est;
            amplitude = redunAmp * (colour_Num(i)^-beta1_est);

        else % Non-redundant Cue conditions
            baseAmp = a2_est * 2^beta2_est;
            amplitude = baseAmp * (colour_Num(i)^-beta2_est);
        end

        % Generate tuning function
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
% Extract the estimated amplitude (a2) and beta parameters
a2_est = estimated_params(1);
beta_est = estimated_params(2:4); % beta1, beta2, beta3

% Define the number of set sizes
setSizes = results.SetSize;

% Calculate the amplitude estimates based on the model
amplitudes = zeros(length(setSizes), 1);
for i = 1:length(setSizes)
    if ismember(i, [1, 2, 3])
        amplitudes(i) = (a2_est * sqrt(2)) / (setSizes(i) ^ beta_est(1));
    elseif ismember(i, [4, 6, 8])
        amplitudes(i) = (a2_est * sqrt(2)) / (setSizes(i) ^ beta_est(2));
    else
        amplitudes(i) = (a2_est * sqrt(2)) / (setSizes(i) ^ beta_est(3));
    end
end

% Create the plot
figure;
hold on;

% Plot amplitude estimates with different markers for different conditions
scatter(setSizes([1, 2, 3]), amplitudes([1, 2, 3]), 100, 'o', 'filled', 'MarkerEdgeColor', 'b'); % Dots for conditions 1, 2, 3
scatter(setSizes([4, 6, 8]), amplitudes([4, 6, 8]), 100, 'x', 'MarkerEdgeColor', 'r', 'LineWidth', 2); % Crosses for conditions 4, 6, 8
scatter(setSizes([5, 7, 9]), amplitudes([5, 7, 9]), 100, '^', 'filled', 'MarkerEdgeColor', 'g'); % Triangles for conditions 5, 7, 9

% Plot the theoretical predictions based on the sample-size amplitude for each condition
baseAmp = a2_est * sqrt(2); % Hypothetical set size 1 base amplitude
theoretical_predictions1 = baseAmp .* (setSizes([1, 2, 3]).^ -0.5);
theoretical_predictions2 = baseAmp .* (setSizes([4, 6, 8]).^ -beta_est(2));
theoretical_predictions3 = baseAmp .* (setSizes([5, 7, 9]).^ -beta_est(3));

% Plotting the theoretical predictions with different line styles
plot(setSizes([1, 2, 3]), theoretical_predictions1, 'k--', 'LineWidth', 2); % Dashed line for conditions 1, 2, 3
plot(setSizes([4, 6, 8]), theoretical_predictions2, 'k-.', 'LineWidth', 2, 'Color', [0.3, 0.3, 0.3]); % Dash-dot line for conditions 4, 6, 8
plot(setSizes([5, 7, 9]), theoretical_predictions3, 'k:', 'LineWidth', 2, 'Color', [0.5, 0.5, 0.5]); % Dotted line for conditions 5, 7, 9

% Set plot labels and title
xlabel('Set Size', 'FontSize', 12);
ylabel('Amplitude (a)', 'FontSize', 12);
title('Amplitude Estimates vs Sample-Size Predictions', 'FontSize', 12);

% Add legend
legend({'Amp est (Cond 1,2,3)', 'Amp est (Cond 4,6,8)', 'Amp est (Cond 5,7,9)', ...
        'Theoretical Prediction (Cond 1,2,3)', 'Theoretical Prediction (Cond 4,6,8)', ...
        'Theoretical Prediction (Cond 5,7,9)'}, ...
        'Location', 'Best', 'FontSize', 14);

% Set axis limits
xlim([0, max(setSizes) + 1]);
ylim([0, max([amplitudes; theoretical_predictions1; theoretical_predictions2; theoretical_predictions3]) * 1.1]);

% Add grid for better readability
grid on;

% Add text labels to each point
labels = {'2/2', '4/4', '6/6', '4/2R', '4/2N', '6/2R', '6/2N', '6/4R', '6/4N'};
for i = 1:length(amplitudes)
    text(setSizes(i), amplitudes(i), labels{i}, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', 'FontSize', 12);
end

hold off;

%%

function [theta, ptheta] = guplcm(P, n)
    a = P(1);
    kappa = P(2);
    theta = linspace(-pi, pi, n); % will wrap around
    utheta = a * exp(kappa * cos(theta)) / (2 * pi); % Tuning function
    ptheta = exp(utheta) / sum(exp(utheta));
    h = theta(2) - theta(1);
    ptheta = ptheta / h;
end
