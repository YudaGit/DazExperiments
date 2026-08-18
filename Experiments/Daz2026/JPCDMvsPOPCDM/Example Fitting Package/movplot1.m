function movlot1(Data, Pred, maxes)
% ========================================================================
% Plot fitted values of circular diffusion model with drift variability
% for Experiment 1.
%     movplot1(Data, Pred, {maxes}) (maxes = [pmax,rtmax] (y-axis,x-axis) 
% ========================================================================

if nargin < 3
   pmax =  1.2;
   rtmax = 1.5;
else
   pmax = maxes(1);
   rtmax = maxes(2);
end

name = 'MOVPLOT1: ';
errmg1 = 'Data should be a 1 x 4 cell array...';

if any(size(Data) ~= [1,4])
   disp('Wrong size data matrix, exiting...')
   return
end

edlab ={'176 ms'; '352 ms'; '529 ms'; '706 ms'};

axhandle = setfig8; 

Theta1 = Data{1}(:,2);
Rt1 = Data{1}(:,3);
Theta2 = Data{2}(:,2);
Rt2 = Data{2}(:,3);
Theta3 = Data{3}(:,2);
Rt3 = Data{3}(:,3);
Theta4 = Data{4}(:,2);
Rt4 = Data{4}(:,3);


% Predictions are a 3 x 4 cell array, 1st row is joint density, 2nd row is accuracy 
ta = Pred{1,1}(1,:);                                  
gtam = Pred{1,1}(2,:);

tb = Pred{1,2}(1,:);
gtbm = Pred{1,2}(2,:);

tc = Pred{1,3}(1,:);
gtcm = Pred{1,3}(2,:);

td = Pred{1,4}(1,:);
gtdm = Pred{1,4}(2,:);

thetaa = Pred{2,1}(1,:);
pthetaa = Pred{2,1}(2,:);

thetab = Pred{2,2}(1,:);
pthetab = Pred{2,2}(2,:);

thetac = Pred{2,3}(1,:);
pthetac = Pred{2,3}(2,:);

thetad = Pred{2,4}(1,:);
pthetad = Pred{2,4}(2,:);


cvec2 = [.60, 0, .60]; % Dark magenta
cvec1 = [.90, .95, .95];   % Kinda blue..

% Accuracy 1
axes(axhandle(1))
histogram(Theta1, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
set(gca, 'Xlim', [-pi, pi])
set(gca, 'Ylim', [0, pmax])
xlabel('Response Error (rad)')
ylabel('Probability density')
label(gca,  .55, .85, edlab{1});
hold
plot(thetaa, pthetaa, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% Accuracy 2
axes(axhandle(3));
histogram(Theta2, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
set(gca, 'Xlim', [-pi, pi])
set(gca, 'Ylim', [0, pmax])
xlabel('Response Error (rad)')
ylabel('Probability density') 
label(gca,  .55, .85, edlab{2});
hold
plot(thetab, pthetab, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% Accuracy 3
axes(axhandle(5))
histogram(Theta3, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
set(gca, 'Xlim', [-pi, pi])
set(gca, 'Ylim', [0, pmax])
xlabel('Response Error (rad)')
ylabel('Probability density')
label(gca,  .55, .85, edlab{3});
hold
plot(thetac, pthetac, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% Accuracy 4
axes(axhandle(7));
histogram(Theta4, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
set(gca, 'Xlim', [-pi, pi])
set(gca, 'Ylim', [0, pmax])
xlabel('Response Error (rad)')
ylabel('Probability density') %%
label(gca,  .55, .85, edlab{4});
hold
plot(thetad, pthetad, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% RT 1%
axes(axhandle(2));
histogram(Rt1, 50, 'Normalization', 'pdf', 'BinLimits', [0,2.0]);
set(gca, 'Xlim', [0, rtmax])  
xlabel('Response Time (s)')
set(gca, 'Ylim', [0, 8.0])
label(gca,  .55, .85, edlab{1});
hold
plot(ta, gtam, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor = cvec1;
c(2).Color = 'k';

% RT 2%
axes(axhandle(4));
histogram(Rt2, 50, 'Normalization', 'pdf', 'BinLimits', [0,2.0]);
set(gca, 'Xlim', [0, rtmax]) 
xlabel('Response Time (s)')
set(gca, 'Ylim', [0, 8.0])
label(gca,  .55, .85, edlab{2});
hold
plot(tb, gtbm, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% RT 3%
axes(axhandle(6));
histogram(Rt3, 50, 'Normalization', 'pdf', 'BinLimits', [0,2.0]);
set(gca, 'Xlim', [0, rtmax])  
xlabel('Response Time (s)')
set(gca, 'Ylim', [0, 8.0])
label(gca,  .55, .85, edlab{3});
hold
plot(tc, gtcm, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor = cvec1;
c(2).Color = 'k';

% RT 4%
axes(axhandle(8));
histogram(Rt4, 50, 'Normalization', 'pdf', 'BinLimits', [0,2.0]);
set(gca, 'Xlim', [0, rtmax])  
xlabel('Response Time (s)')
set(gca, 'Ylim', [0, 8.0])
label(gca, .55, .85, edlab{4});
hold
plot(td, gtdm, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';





