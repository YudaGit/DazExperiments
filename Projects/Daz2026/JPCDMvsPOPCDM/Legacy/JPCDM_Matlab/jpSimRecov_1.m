% =========================================================================
% Learning to fit the JPCDM 
%==========================================================================

clear; clc;
rng(1); % setting seed

% 1. Choose "true" parameters for simulation

% P =   [vnorm, kappa, eta,  psi,   a,   ter, st]
Pgen1 = [10.0,  1.0,   0.30, -0.70, 2.3, 0.1, 0.1];
Pgen2 = [10.0,  5.0,   0.30, 0.40,  2.3, 0.1, 0.1];

tmax = 3.0;
nTrials = 5000;

% 2. Generate Gt, Theta and T
[T1,Gt1, Theta1, Ptheta1, Mt1] = jpcdm1(Pgen1, tmax);
[T2,Gt2, Theta2, Ptheta2, Mt2] = jpcdm1(Pgen2, tmax);

% 3. Create prob mass grid
ThetaOpen1 = Theta1(1:end-1);
ThetaOpen2 = Theta2(1:end-1);
GtOpen1 = Gt1(1:end-1, :); % delete the wrap around row
GtOpen2 = Gt2(1:end-1, :);

dtheta1 = ThetaOpen1(2)-ThetaOpen1(1);
dtheta2 = ThetaOpen2(2)-ThetaOpen2(1);

dt1 = T1(2) - T1(1);
dt2 = T2(2) - T2(1);

cellProb1 = GtOpen1 * dt1 * dtheta1;
cellProb1 = cellProb1(:);
cellProb1 = max(cellProb1, 0);
cellProb1 = cellProb1 / sum(cellProb1);

cellProb2 = GtOpen2 * dt2 * dtheta2;
cellProb2 = cellProb2(:);
cellProb2 = max(cellProb2, 0);
cellProb2 = cellProb2 / sum(cellProb2);

% 4, sample Response angle and Rt from the joint density

cdf1 = cumsum(cellProb1);
cdf1(end) = 1;
unif1 = rand(nTrials, 1);

cdf2 = cumsum(cellProb2);
cdf2(end) = 1;
unif2 = rand(nTrials, 1);

sampledCell1 = arrayfun(@(x) find(cdf1 >= x, 1, "first"), unif1);

[angleIdx1, tIdx1] = ind2sub(size(GtOpen1), sampledCell1);

sampledCell2 = arrayfun(@(x) find(cdf2 >= x, 1, "first"), unif2);

[angleIdx2, tIdx2] = ind2sub(size(GtOpen2), sampledCell2);


angle1 = ThetaOpen1(angleIdx1)' + (rand(nTrials, 1)-0.5) * dtheta1; % draw angle using idx and add jitter
angle1 = mod(angle1+pi, 2*pi) - pi; % wrap around and prevent going outside the circle

angle2 = ThetaOpen2(angleIdx2)' + (rand(nTrials, 1)-0.5) * dtheta2; % draw angle using idx and add jitter
angle2 = mod(angle2+pi, 2*pi) - pi; % wrap around and prevent going outside the circle

rt1 = T1(tIdx1)' + (rand(nTrials, 1) - 0.5) * dt1;
rt1 = max(rt1, 0);

rt2 = T2(tIdx2)' + (rand(nTrials, 1) - 0.5) * dt2;
rt2 = max(rt2, 0);

simData1 = table(angle1, rt1, ...
    'VariableNames', {'rAngle', 'rt'});

simData2 = table(angle2, rt2, ...
    'VariableNames', {'rAngle', 'rt'});

simData1.cond = ones(height(simData1), 1);
simData2.cond = 2 * ones(height(simData2), 1);
simDataC = [simData1; simData2];

% -------------------------------------------------------------------------
% 4. Quick checks and plots
% -------------------------------------------------------------------------
fprintf('Simulated %d trials per condition, %d total.\n', nTrials, height(simDataC));

fprintf('Cond 1 Generating P = [vnorm, kappa, eta, psi, a, ter, st]\n');
disp(Pgen1);
fprintf('Cond 2 Generating P = [vnorm, kappa, eta, psi, a, ter, st]\n');
disp(Pgen2);

figure;
tiledlayout(1, 2);
nexttile;
histogram(simDataC.rAngle(simDataC.cond == 1), 30, 'Normalization', 'pdf');
hold on;
histogram(simDataC.rAngle(simDataC.cond == 2), 30, 'Normalization', 'pdf');
legend('Cond 1', 'Cond 2');
xlabel('Response angle');
ylabel('Density');
title('Simulated angles by condition');
nexttile;
histogram(simDataC.rt(simDataC.cond == 1), 30, 'Normalization', 'pdf');
hold on;
histogram(simDataC.rt(simDataC.cond == 2), 30, 'Normalization', 'pdf');
legend('Cond 1', 'Cond 2');
xlabel('RT');
ylabel('Density');
title('Simulated RTs by condition');

%=======================
% Fit Pgen simulated data for parameter recovery
%=======================

% Q = [vnorm, eta, a, ter, st, kappa1, psi1, kappa2, psi2]
lb = [0.01, 0.01, 0.10, 0.00, 0.00, 0.01, -1.00, 0.01, -1.00];
ub = [15.0, 1.00, 5.00, 0.50, 0.40, 20.0,  1.00, 20.0,  1.00];

nStarts = 10;

Qgen = [Pgen1(1), Pgen1(3), Pgen1(5), Pgen1(6), Pgen1(7), ...
        Pgen1(2), Pgen1(4), Pgen2(2), Pgen2(4)];

Qstarts = lb + rand(nStarts, length(lb)) .* (ub - lb);

%               [vnorm, eta,   a,    ter,   st,   kappa1, psi1,  kappa2, psi2]
Qstarts(1, :) = [5.0,   0.50,  0.90, 0.15,  0.04, 0.1,    0.00,  4.0,    0.50];
Qstarts(2, :) = [9.0,   0.20,  0.90, 0.15,  0.04, 2.0,    0.00,  1.0,    -0.5];

options = optimset('Display', 'off', ...
    'MaxIter', 1500, ...
    'MaxFunEvals', 6000, ...
    'TolX', 1e-5, ...
    'TolFun', 1e-5);

allQfit = zeros(nStarts, length(lb));
allNLL = zeros(nStarts, 1);

for s = 1:nStarts
    qstart = p_to_q(Qstarts(s, :), lb, ub);
    obj = @(q) jpcdm_nll_2cond(q_to_p(q, lb, ub), simDataC, tmax);

    qfit = fminsearch(obj, qstart, options);

    allQfit(s, :) = q_to_p(qfit, lb, ub);
    allNLL(s) = jpcdm_nll_2cond(allQfit(s, :), simDataC, tmax);
end

[bestNLL, bestIdx] = min(allNLL);
Qfit = allQfit(bestIdx, :);

Pfit1 = [Qfit(1), Qfit(6), Qfit(2), Qfit(7), Qfit(3), Qfit(4), Qfit(5)];
Pfit2 = [Qfit(1), Qfit(8), Qfit(2), Qfit(9), Qfit(3), Qfit(4), Qfit(5)];

fprintf('\nGenerating Q = [vnorm, eta, a, ter, st, kappa1, psi1, kappa2, psi2]\n');
disp(Qgen);
fprintf('Best fitted Q = [vnorm, eta, a, ter, st, kappa1, psi1, kappa2, psi2]\n');
disp(Qfit);

fprintf('Cond 1 generating P = [vnorm, kappa, eta, psi, a, ter, st]\n');
disp(Pgen1);
fprintf('Cond 1 fitted P = [vnorm, kappa, eta, psi, a, ter, st]\n');
disp(Pfit1);
fprintf('Cond 2 generating P = [vnorm, kappa, eta, psi, a, ter, st]\n');
disp(Pgen2);
fprintf('Cond 2 fitted P = [vnorm, kappa, eta, psi, a, ter, st]\n');
disp(Pfit2);

fprintf('NLL at Qgen: %.4f\n', jpcdm_nll_2cond(Qgen, simDataC, tmax));
fprintf('Best fitted NLL: %.4f\n', bestNLL);
fprintf('Best start index: %d\n', bestIdx);

[Tgen1, Gtgen1, Thetagen1, Pthetag1, Mtgen1] = jpcdm1(Pgen1, tmax);
[Tgen2, Gtgen2, Thetagen2, Pthetag2, Mtgen2] = jpcdm1(Pgen2, tmax);
[Tfit1, Gtfit1, Thetafit1, Pthetaf1, Mtfit1] = jpcdm1(Pfit1, tmax);
[Tfit2, Gtfit2, Thetafit2, Pthetaf2, Mtfit2] = jpcdm1(Pfit2, tmax);

figure;
tiledlayout(2, 2);

nexttile;
plot(Thetagen1, Pthetag1, 'k-', 'LineWidth', 2); hold on;
plot(Thetafit1, Pthetaf1, 'r--', 'LineWidth', 2);
legend('Generating', 'Fitted');
xlabel('Response angle');
ylabel('Ptheta');
title('Cond 1 response-angle distribution');

nexttile;
plot(Thetagen1, Mtgen1, 'k-', 'LineWidth', 2); hold on;
plot(Thetafit1, Mtfit1, 'r--', 'LineWidth', 2);
legend('Generating', 'Fitted');
xlabel('Response angle');
ylabel('Mean RT');
title('Cond 1 mean RT by angle');

nexttile;
plot(Thetagen2, Pthetag2, 'k-', 'LineWidth', 2); hold on;
plot(Thetafit2, Pthetaf2, 'r--', 'LineWidth', 2);
legend('Generating', 'Fitted');
xlabel('Response angle');
ylabel('Ptheta');
title('Cond 2 response-angle distribution');

nexttile;
plot(Thetagen2, Mtgen2, 'k-', 'LineWidth', 2); hold on;
plot(Thetafit2, Mtfit2, 'r--', 'LineWidth', 2);
legend('Generating', 'Fitted');
xlabel('Response angle');
ylabel('Mean RT');
title('Cond 2 mean RT by angle');

figure;
tiledlayout(1, 2);

nexttile;
plot(Thetagen1, (Mtfit1 - Mtgen1) * 1000, 'LineWidth', 2);
xlabel('Response angle');
ylabel('Fitted - Generating Mean RT (ms)');
title('Cond 1 mean RT difference');
yline(0, 'k--');

nexttile;
plot(Thetagen2, (Mtfit2 - Mtgen2) * 1000, 'LineWidth', 2);
xlabel('Response angle');
ylabel('Fitted - Generating Mean RT (ms)');
title('Cond 2 mean RT difference');
yline(0, 'k--');

[rtGen1, rtFit1] = marginal_rt_pair(Thetagen1, Gtgen1, Gtfit1);
[rtGen2, rtFit2] = marginal_rt_pair(Thetagen2, Gtgen2, Gtfit2);

figure;
tiledlayout(1, 2);

nexttile;
plot(Tgen1, rtGen1, 'k-', 'LineWidth', 2); hold on;
plot(Tfit1, rtFit1, 'r--', 'LineWidth', 2);
legend('Generating', 'Fitted');
xlabel('RT');
ylabel('Density');
title('Cond 1 marginal RT distribution');

nexttile;
plot(Tgen2, rtGen2, 'k-', 'LineWidth', 2); hold on;
plot(Tfit2, rtFit2, 'r--', 'LineWidth', 2);
legend('Generating', 'Fitted');
xlabel('RT');
ylabel('Density');
title('Cond 2 marginal RT distribution');

%=======================
% Local helper functions
%=======================

function [rtGen, rtFit] = marginal_rt_pair(Theta, GtGen, GtFit)
    ThetaOpen = Theta(1:end-1);
    GtGenOpen = GtGen(1:end-1, :);
    GtFitOpen = GtFit(1:end-1, :);
    dtheta = ThetaOpen(2) - ThetaOpen(1);
    rtGen = sum(GtGenOpen, 1) * dtheta;
    rtFit = sum(GtFitOpen, 1) * dtheta;
end

function q = p_to_q(P, lb, ub)
    z = (P - lb) ./ (ub - lb);
    z = min(max(z, 1e-9), 1 - 1e-9);
    q = log(z ./ (1 - z));
end

function P = q_to_p(q, lb, ub)
    z = 1 ./ (1 + exp(-q));
    P = lb + (ub - lb) .* z;
end