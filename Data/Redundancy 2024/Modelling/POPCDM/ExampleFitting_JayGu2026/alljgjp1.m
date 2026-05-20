% ============================================================================
%  Batch fit of CDM to Jay Gu's desaturation task
% Subjects, jg, aq
% P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta, beta1:beta2]  
%          1:8     9:16   17:20       21:24      25:28  29:32   33   34   35:38    39   40   41:42
% ============================================================================
load Jay1

Sel = ones(1, 42);  Sel([10    11    12    13    14    15    16    22    23    24]) = 0;
Pfix = ones(1,10); % Values of these don't matter as all set internally if Sel = 0
% Single free kappa. Power law with the same kappa(1) for saturated and desaturated stimuli.
% Single Jones-Pewsey shape parameter Psi for all set sizes. 

[Pest1, Stat1, Pred1]=set_jgjp1(Pfix, Sel, jgam)
save jgcdm3
disp('**** Completed jgam')

%[Pest2, Stat2, Pred2]=set_jgjp1(Pfix, Sel, aqam)
%save jgcdm1
%disp('**** Completed aqam')

