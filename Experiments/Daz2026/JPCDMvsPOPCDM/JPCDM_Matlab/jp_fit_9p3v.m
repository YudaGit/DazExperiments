% =========================================================================
% Fit JPCDM 9p3v: free condition-specific psi, shared kappa,
% three grouped vnorm values and three color-group ter values
% =========================================================================

clear; clc;

fitMode = "full";
fitOutput = run_jpcdm_grouped_vnorm_fit("psi", fitMode);

% Expose familiar workspace variables for inspection and saving.
fitResultPsiCond = fitOutput.fitResults;
allParticipantFits = fitOutput.allParticipantFits;
modelPsiCond = fitOutput.model;
d = fitOutput.data;
condLevels = fitOutput.condLevels;
targetIDs = fitOutput.targetIDs;
lb = fitOutput.lb;
ub = fitOutput.ub;
etaTangentialEffective = fitOutput.etaTangentialEffective;
stFixed = fitOutput.stFixed;
tmax = fitOutput.tmax;
nStarts = fitOutput.nStarts;
rngSeed = fitOutput.rngSeed;
