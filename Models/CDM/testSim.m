addpath('C:\Users\Yuda\Documents\GitHub\DazExperiments\Models\CDM');  % or your repo path
rng(42);   % reproducibility
P = [3.0, 0.5, 0.5, 2.0, 0.35, 0.1, 0.85];  % example: [vnorm, etar, etat, a, Ter, st, q]
tmax = 3;
ntrials = 5000;
[x, t, rx, tx, trx] = simcdm5(P, tmax, ntrials, 0);
% trx(:,1) = error angle (rad), trx(:,2) = RT (s) — same layout cdmsimll5 expects in Data(:,2:3)
histogram(rx, 36, 'Normalization', 'pdf');
figure; histogram(tx, 40, 'Normalization', 'pdf');