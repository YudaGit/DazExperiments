% ============================================================================
%  Batch fit of CDM to Jay Gu's desaturation task
% Subjects, jg, aq
% P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta, beta1:beta2]  
%          1:8     9:16   17:20       21:24     25:28  29:32   33   34   35:38    39   40   41:42
% Categories, st < .2,  Single Beta
% ============================================================================
load Jay5

do_bias = 1;
% Single free kappa. Power law with the same kappa(1) free
% Single Jones-Pewsey shape parameter Psi for all set sizes. 
% Set categories to zero

Sel = ones(1, 42);  
Sel([10:12, 14:16,   18:20     22:24, 42]) = 0; % 12 elements (single beta)
%    k2:k4 k6:k8  eta2:eta4,  Psi2:Psi4
Pfix1 = [1,1,1, 1,1,1, 1,1,1, 0,0,0, 0.5]; % set the dummy Psi parameters to zero to avoid penalty
if do_bias
    Pfix = Pfix1;
else
    Sel([25:28, 29:32, 33, 40]) = 0;
    %           B         A   alpha, delta
    Pfix2 = [zeros(1,4), -pi, -pi/2, pi/2, pi, 3.0, 1.0];
    Pfix = [Pfix1, Pfix2];
end
         
[Pest1, Stat1, Pred1]=set_jgjp5(Pfix, Sel, jgai)
save jgcdm7
disp('**** Completed jgai')

[Pest2, Stat2, Pred2]=set_jgjp5(Pfix, Sel, aqai)
save jgcdm7
disp('**** Completed aqai')

[Pest3, Stat3, Pred3]=set_jgjp5(Pfix, Sel, jdai)
save jgcdm7
disp('**** Completed jdai')


% myCluster = parcluster('Processes') , delete(myCluster.Jobs) 
