% SIMCDM5_DEMO_CONDITIONS — Simulate spike-and-slab CDM for multiple conditions.
%
% Mirrors slabcdmsim3: each condition has its own [vnorm, etar, etat, a, Ter, st, q].
% Shared etat, a, st in the full model are applied identically to each row below for demo.
%
% Usage: addpath(this folder), then run this script in MATLAB.

clear; clc;
rng(42);

tmax = 3;
ntrials = 3000;  % per condition; increase for smoother histograms

% --- Example: 4 discriminability levels (tweak vnorm / q / Ter per "easier/harder") ---
etat = 0.35;
a    = 2.0;
st   = 0.10;

% Rows: [vnorm, etar, etat, a, Ter, st, q]
Pcond = [
    2.5, 0.6, etat, a, 0.32, st, 0.88;   % condition 1 (e.g. easiest)
    2.2, 0.7, etat, a, 0.34, st, 0.82;
    1.8, 0.8, etat, a, 0.36, st, 0.75;
    1.4, 0.9, etat, a, 0.38, st, 0.65   % hardest
];

ncond = size(Pcond, 1);
trx_cell = cell(ncond, 1);
rx_cell  = cell(ncond, 1);
tx_cell  = cell(ncond, 1);

for c = 1:ncond
    P = Pcond(c, :);
    [~, ~, rx, tx, trx] = simcdm5(P, tmax, ntrials, 0);
    trx_cell{c} = trx;
    rx_cell{c}  = rx(:);
    tx_cell{c}   = tx(:);
end

% --- Optional: single table-like matrix with condition id for export / stats ---
% columns: [condition_id, angle_rad, rt_sec]
Data_stacked = [];
for c = 1:ncond
    tr = trx_cell{c};
    Data_stacked = [Data_stacked; c * ones(size(tr,1),1), tr]; %#ok<AGROW>
end

% --- Plots: error angle (wrap to [-pi,pi] already) and RT per condition ---
figure('Color', 'w', 'Position', [100 100 900 400]);

subplot(1, 2, 1);
hold on;
edges_a = linspace(-pi, pi, 37);
for c = 1:ncond
    histogram(rx_cell{c}, edges_a, 'Normalization', 'pdf', 'DisplayName', sprintf('cond %d', c));
end
hold off;
xlabel('response angle (rad)'); ylabel('pdf');
title('Angular responses'); legend('Location', 'best');

subplot(1, 2, 2);
hold on;
edges_t = linspace(0, tmax + 0.5, 40);
for c = 1:ncond
    histogram(tx_cell{c}, edges_t, 'Normalization', 'pdf', 'DisplayName', sprintf('cond %d', c));
end
hold off;
xlabel('RT (s)'); ylabel('pdf');
title('RT'); legend('Location', 'best');

% --- For slabcdmsim3-style cells: Data{k} has arbitrary col1, then angle, RT ---
Data = cell(ncond, 1);
for c = 1:ncond
    tr = trx_cell{c};
    Data{c} = [(1:size(tr,1))', tr(:,1), tr(:,2)];  % cols 2:3 = angle, RT
end
