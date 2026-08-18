% =========================================================================
% Fit POPCDM theory models
%
% Current naming
%   H0a : baseline 1 kappa, 9 alphas (17 free)
%   H0b : baseline 1 alpha, 9 kappas (17 free)
%   H1  : H0a with 3-beta power-law alpha (12 free)
% Shared: 3 set-size vnorms (S2/S4/S6); singleton eta1, a, ter, st
%         eta2 = exp(-6)
%
% Optimizer: MultiStart-style fmincon, 16 starts, MaxIter=2000
% H0b and H1 warm-start from H0a (or legacy H3a files) when available
% =========================================================================

clear; clc;

% "smoke" = first participant, first listed hypothesis, short budget.
% "full"  = all five participants x selected hypotheses, 16 starts.
fitMode = "full";

hypothesisNames = ["H0a", "H0b"]; 
        
fitOutput = run_popcdm_theory_fit(hypothesisNames, fitMode);

% Expose workspace variables for inspection.
comparisonRows = fitOutput.comparisonRows;
allModelResults = fitOutput.allModelResults;
catalog = fitOutput.catalog;
d = fitOutput.data;
condLevels = fitOutput.condLevels;
resultsFolder = fitOutput.resultsFolder;

fprintf('\nDone. Results folder:\n%s\n', resultsFolder);
disp(comparisonRows);
