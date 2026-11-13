% =========================================================================
% Fit POPCDM 9a3v: free condition-specific alpha, shared kappa,
% three grouped vnorm values
% =========================================================================

clear; clc;

% POPCDM alpha is the analogue of the condition-specific second
% drift-angle-distribution parameter in JPCDM's jp_fit_9p3v.
% Change to "full" only after the smoke run succeeds.
fitMode = "full";
fitOutput = run_popcdm_grouped_vnorm_fit("alpha", fitMode);

% Expose familiar workspace variables for inspection and saving.
fitResultAlphaCond = fitOutput.fitResults;
allParticipantFits = fitOutput.allParticipantFits;
modelAlphaCond = fitOutput.model;
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
