function emvplot11x(Data, Pred, maxes)
% ========================================================================
% Plot fitted values of circular diffusion model with drift variability
% to Elaine's RDM task
%     emovplot11x(Data, Pred, {maxes})
% Works with either 2-column or 3-column data
% ========================================================================
name = 'EMOVPLOT11X: ';
errmg1 = 'Data should be a 1 x 3 cell array from <makelike>...';

if nargin < 3
   pmax =  2.0;
   rtmax = 3.5;
else
   pmax = maxes(1);
   rtmax = maxes(2);
end

if size(Data) ~= [1,3]
   disp('Wrong size data matrix, exiting...')
   return
else
  sz = size(Data{1})
  two_column = sz(2) == 2; % Canonical orientation 
end
two_column

axhandle = setfig4x;
if two_column % Canonical orientation
    Theta1 = Data{1}(:,1);
    Rt1 = Data{1}(:,2);
    Theta2 = Data{2}(:,1);
    Rt2 = Data{2}(:,2);
else
    Theta1 = Data{1}(:,2);
    Rt1 = Data{1}(:,3);
    Theta2 = Data{2}(:,2);
    Rt2 = Data{2}(:,3);
end
% Predictions are a 2 x 3 cell array, 1st row is joint density, 2nd row is accuracy 
ta = Pred{1,1}(1,:);
gtam = Pred{1,1}(2,:);

tb = Pred{1,2}(1,:);
gtbm = Pred{1,2}(2,:);

thetaa = Pred{2,1}(1,:);
pthetaa = Pred{2,1}(2,:);

thetab = Pred{2,2}(1,:);
pthetab = Pred{2,2}(2,:);

cvec2 = [.60, 0, .60]   % Dark magenta
cvec1 = [.90, .95, .95];   % Kinda blue..
%Accuracy 25%
axes(axhandle(1))
histogram(Theta1, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
set(gca, 'Xlim', [-pi, pi])
set(gca, 'Ylim', [0, pmax])  
xlabel('Response Error (rad)')
ylabel('Probability density')
label(gca, .65, .85, '50%');
hold
plot(thetaa, pthetaa, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% Accuracy high
axes(axhandle(3));
histogram(Theta2, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
set(gca, 'Xlim', [-pi, pi])
set(gca, 'Ylim', [0, pmax]) 
xlabel('Response Error (rad)')
ylabel('Probability density')
label(gca, .65, .85, '25%');
hold
plot(thetab, pthetab, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';


% RT 25%
axes(axhandle(2));
histogram(Rt1, 50, 'Normalization', 'pdf', 'BinLimits', [0,4.5]);
set(gca, 'Xlim', [0, rtmax])
xlabel('Response Time (s)')
set(gca, 'Ylim', [0, 2.5])  
label(gca, .65, .85, '50%');
hold
plot(ta, gtam, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor = cvec1;
c(2).Color = 'k';

% RT 50%
axes(axhandle(4));
histogram(Rt2, 50, 'Normalization', 'pdf', 'BinLimits', [0,4.5]);
set(gca, 'Xlim', [0, rtmax])
xlabel('Response Time (s)')
set(gca, 'Ylim', [0, 2.5]) % was 3.75
label(gca, .65, .85, '25%');
hold
plot(tb, gtbm, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';





