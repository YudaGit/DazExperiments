% ============================================================================
%  Batch fit of CDM to Jay Gu's desaturation task
% Subjects, jg, aq
% P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta, beta1:beta2]  
%          1:8     9:16   17:20       21:24      25:28  29:32   33   34   35:38    39   40   41:42
%W No categories, st < .2
% ============================================================================
load Jay3


% Single free kappa. Power law with the same kappa(1) for saturated and desaturated stimuli.
% Single Jones-Pewsey shape parameter Psi for all set sizes. 
% Set categories to zero
Sel = ones(1, 42);  
Sel([10    11    12    13    14    15    16    22    23    24]) = 0;
%     k2...k8  etas free,  Psi...Psi4
Pfix1 = ones(1,10);
Sel([25:33,40]) = 0;
Pfix2 = [zeros(1,4), -pi, -pi/2, pi/2, pi, 3.0, 1.0];
%           B         A   alpha, delta
Pfix = [Pfix1, Pfix2];
         
[Pest1, Stat1, Pred1]=set_jgjp3(Pfix, Sel, jgai)
save jgcdm4
disp('**** Completed jgai')

[Pest2, Stat2, Pred2]=set_jgjp3(Pfix, Sel, aqai)
save jgcdm4
disp('**** Completed aqai')

% myCluster = parcluster('Processes') , delete(myCluster.Jobs) 
