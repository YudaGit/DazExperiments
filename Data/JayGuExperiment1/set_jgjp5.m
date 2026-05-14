function [Pest, Stat, Pred] = set_jgjp5(Pfix, Sel, Data)
% ==============================================================================================
% Fit simulated CDM by particle swarm optimization to Jay Gu's desaturation experiment
%     [Pest, Stat, Pred] = set_jgjp5(Pfix, Sel, Data);
% P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta, beta1:beta2]  
%        1:8     9:16   17:20       21:24      25:28  29:32   33   34   35:38    39   40   41:42
% 27/04/26
% =============================================================================================

   threehours = 10800;
         
   name = 'SET_JPJG5: ';
   errmg1 = 'Incorrect length selector vector, exiting...';
   errmg2 = 'Number of fixed entries in Sel does not match length Sel';
   errmg3 = 'Data should be a 2 x 4 cell array';

   np = 42;
   if length(Sel) ~= np
        [name, errmg1], length(Sel), return;
   end
   if length(Pfix) + sum(Sel) ~= np
        [name, errmg2], sum(Sel), length(Pfix), return;
   end       
   if any(size(Data) ~= [2,4])
        [name, errmg3], size(Data), return;
   end
   nfree = np - length(Pfix); % number of parameters actually estimated      

   jgjp_dummy = @(x) jgjp5(x, Pfix, Sel, Data);

   % Just duplicate the bounds from within inside jgjp5
    
   U2 = ones(1,2);
   U4 = ones(1,4);
   U8 = ones(1,8);  

   % -------------------------------------------------------------------------------------------------
   % P = [nrm1:nrm8 k1:k8, eta1..eta4, Psi1..Psi4,   B,     A,   alpha, a, Ter1:Ter4 st delta beta1:beta2]  
   %        1:8     9:16   17:20       21:24      25:28  29:32    33    34   35:38   39   40   41:42   
   % -------------------------------------------------------------------------------------------------
   Ub = [7.5*U8, 9.0*U8,  4.0*U4,   1.0*U4,  9.0*U4,  pi*U4+0.1, 10.0, 7.0, 1.5*U4, 0.75, 1.0, 1.0*U2]; 
   Lb = [  0*U8,    0*U8,  0*U4,    -2.0*U4,    0*U4, -pi*U4-0.1,  0.2,  0.5,  0*U4,   0, 0,    0*U2]; 
   %Pub =[7.2*U8, 6.0*U8,  3.5*U4,   0.05*U4, 8.0*U4,  pi*U4+0.05, 9.0, 6.0, 1.0*U4, 0.70, 0.99, 0.9*U2];  
   %Plb =[0.5*U8,  0.1*U8,  0.01*U4, -1.95*U4,   0*U4, -pi*U4-0.05, 1.3, 0.1, .15*U4,  0, 0.01, .25*U2]; 
  
   Ub = Ub(Sel==1)
   Lb = Lb(Sel==1)
   hybridopts = optimoptions('fmincon','Display','iter','Algorithm','interior-point');
   options.HybridFcn =@fmincon;
   options = optimoptions('particleswarm', 'UseParallel', true, 'UseVectorized', false, 'Display', 'iter', 'MaxTime', threehours);
   options = optimoptions(options, 'HybridFcn', {@fmincon, hybridopts});
   [xpso,fpso,flgpso,opso] = particleswarm(jgjp_dummy, nfree, Lb, Ub, options)
   ll2 = fpso; % Removed 2 x here, already done in fitting routine!
   apen = 2 * sum(Sel);
   bpen = sum(Sel) * log((length(Data{1}) + length(Data{2}) + length(Data{3}) + length(Data{4})));
   Stat = [fpso, ll2, ll2 + apen, ll2 + bpen, sum(Sel)]
   [~, ~, ~, Pred] = jgjp_dummy(xpso) % 06/05 Changed to dummy call to keep up to date
   Pest = zeros(1, np);
   Pest(Sel==1) = xpso;
   Pest(Sel==0) = Pfix;

   % Assemble parameter vector.
   P = zeros(1,np);
   P(Sel==1) = xpso;
   P(Sel==0) = Pfix


% Maybe not needed for CDM?
%myCluster = parcluster('local')
%delete(myCluster.Jobs)


   

