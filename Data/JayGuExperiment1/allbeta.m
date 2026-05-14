% =================================================================================
% Finish off the particle swawm fits for 2 x beta and 1 x beta models
% These were the bias models
%      allbeta
% =================================================================================
load Jay5
setopt
% 1 x beta bias model
load jgcdm7

Statbeta1 = zeros(3, 3);
Paramsbeta1 = zeros(3, 42);
Predbeta1 = cell(1,3);

P = Pest1;
Data = jgai;
pest = fminsearch(@jgjp5, P(Sel==1), options, P(Sel==0), Sel, Data);
P(Sel==1) = pest;
[ll,a,b,Pred] = jgjp5(P(Sel==1), P(Sel==0), Sel, Data);
Statbeta1(1,:) = [ll, a, b];
Paramsbeta1(1,:) = P;
Predbeta1{1,1} = Pred;

P = Pest2;
Data = aqai;
pest = fminsearch(@jgjp5, P(Sel==1), options, P(Sel==0), Sel, Data);
P(Sel==1) = pest;
[ll,a,b,Pred] = jgjp5(P(Sel==1), P(Sel==0), Sel, Data);
Statbeta1(2,:) = [ll, a, b];
Paramsbeta1(2,:) = P;
Predbeta1{1,2} = Pred;

P = Pest3;
Data = jdai;
pest = fminsearch(@jgjp5, P(Sel==1), options, P(Sel==0), Sel, Data);
P(Sel==1) = pest;
[ll,a,b,Pred] = jgjp5(P(Sel==1), P(Sel==0), Sel, Data);
Statbeta1(3,:) = [ll, a, b];
Paramsbeta1(3,:) = P;
Predbeta1{1,3} = Pred;

save allbeta

% 2 x beta bias model
load jgcdm5

Statbeta2 = zeros(3, 3);
Paramsbeta2 = zeros(3, 42);
Predbeta2 = cell(1,3);

P = Pest1;
Data = jgai;
pest = fminsearch(@jgjp5, P(Sel==1), options, P(Sel==0), Sel, Data);
P(Sel==1) = pest;
[ll,a,b,Pred] = jgjp5(P(Sel==1), P(Sel==0), Sel, Data);
Statbeta2(1,:) = [ll, a, b];
Paramsbeta2(1,:) = P;
Predbeta2{1,1} = Pred;

P = Pest2;
Data = aqai;
pest = fminsearch(@jgjp5, P(Sel==1), options, P(Sel==0), Sel, Data);
P(Sel==1) = pest;
[ll,a,b,Pred] = jgjp5(P(Sel==1), P(Sel==0), Sel, Data);
Statbeta2(2,:) = [ll, a, b];
Paramsbeta2(2,:) = P;
Predbeta2{1,2} = Pred;

P = Pest3;
Data = jdai;
pest = fminsearch(@jgjp5, P(Sel==1), options, P(Sel==0), Sel, Data);
P(Sel==1) = pest;
[ll,a,b,Pred] = jgjp5(P(Sel==1), P(Sel==0), Sel, Data);
Statbeta2(3,:) = [ll, a, b];
Paramsbeta2(3,:) = P;
Predbeta2{1,3} = Pred;

save allbeta

