% ============================================================================
%  Batch fit of CDM to Jay Gu's desaturation task
% Subjects, jg, aq
% P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta, beta1:beta2]  
%          1:8     9:16   17:20       21:24      25:28  29:32   33   34   35:38    39   40   41:42
%W No categories
% ============================================================================
load Jay3


% Single free kappa. Power law with the same kappa(1) for saturated and desaturated stimuli.
% Single Jones-Pewsey shape parameter Psi for all set sizes. 
% Set categories to zero
Sel = ones(1, 42);  Sel([10    11    12    13    14    15    16    22    23    24]) = 0;
Sel([25:33,40]) = 0;
Pfix = [ones(1,10), zeros(1,4), -3.0827   -0.0053    3.0    0.1137    2.1691, 1.0]  % delta = 1.0
[Pest1, Stat1, Pred1]=set_jgjp1(Pfix, Sel, jgai)
save jgcdm3
disp('**** Completed jg')

%[Pest2, Stat2, Pred2]=set_jgjp1(Pfix, Sel, aqai)
%save jgcdm3
%disp('**** Completed aq')

% myCluster = parcluster('Processes') , delete(myCluster.Jobs) 
