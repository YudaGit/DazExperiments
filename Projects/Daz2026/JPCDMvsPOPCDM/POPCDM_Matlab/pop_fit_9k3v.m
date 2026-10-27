% =========================================================================
% Fit POPCDM 9k3v: free condition-specific kappa, shared alpha,
% three grouped vnorm values
% =========================================================================

clear; clc;

% Change to "smoke" before the first test run. "full" matches jp_fit_9k3v.
fitMode = "full";
fitOutput = run_popcdm_grouped_vnorm_fit("kappa", fitMode);

% Expose familiar workspace variables for inspection and saving.
fitResultKappaCond = fitOutput.fitResults;
allParticipantFits = fitOutput.allParticipantFits;
modelKappaCond = fitOutput.model;
d = fitOutput.data;
condLevels = fitOutput.condLevels;
targetIDs = fitOutput.targetIDs;
lb = fitOutput.lb;
ub = fitOutput.ub;
eta2Fixed = fitOutput.eta2Fixed;
stFixed = fitOutput.stFixed;
nw = fitOutput.nw;
h = fitOutput.h;
tmax = fitOutput.tmax;
nStarts = fitOutput.nStarts;
rngSeed = fitOutput.rngSeed;
