function mvw23(Data, Pred, ymax)
% ========================================================================
% Plot fitted values of circular diffusion model with drift variability
% to VWM Experiment (4 set sizes)
% 10/12/22 - Now takes cell array of Gstuff and Preds as argument
%     mvw23(Data, Pred, {[emax, rtmax, rtdenmax]})
% or
%     mvw23(Data, Pred, {[emax, rtmax]})
% or
%     mvw23(Data, Pred)
% ========================================================================

% Take cell structure as argument
Preds = Pred{1,1};
Gstuff = Pred{2,1};


if nargin < 3
   emax = 1.2;
   rtmax = 1.5;
   rtdenmax = 4.5; % hard-wired
else
   if size(ymax) == [1,3]
       emax = ymax(1);
       rtmax = ymax(2);
       rtdenmax = ymax(3);
   else
       emax = ymax(1);
       rtmax = ymax(2);
       rtdenmax = 4.5; % hard-wired
   end
end

name = 'FEUPLOT11X: ';
errmg1 = 'Data should be a 1 x 4 cell array...';

if any(size(Data) ~= [1,4])
   disp('Wrong size data matrix, exiting...')
   return
end

%axhandle = setfig8narrow;
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
ta = Preds{1,1}(1,:);                                  
gtam = Preds{1,1}(2,:); % ??

tb = Preds{1,2}(1,:);
gtbm = Preds{1,2}(2,:); %??

tc = Preds{1,3}(1,:);
gtcm = Preds{1,3}(2,:); 

td = Preds{1,4}(1,:);
gtdm = Preds{1,4}(2,:);

thetaa = Preds{2,1}(1,:);
pthetaa = Preds{2,1}(2,:);

thetab = Preds{2,2}(1,:);
pthetab = Preds{2,2}(2,:);

thetac = Preds{2,3}(1,:);
pthetac = Preds{2,3}(2,:);

thetad = Preds{2,4}(1,:);
pthetad = Preds{2,4}(2,:);


cvec2 = [.60, 0, .60]; % Dark magenta
cvec1 = [.90, .95, .95];   % Kinda blue..

% Accuracy 1
axes(axhandle(1))
histogram(Theta1, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
set(gca, 'Xlim', [-pi, pi])
set(gca, 'Ylim', [0, emax])
set(gca, 'XTick', []);
set(gca, 'XTickLabel', {});
ylabel('Density')
label(gca,  .55, .80, 'm=1');
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
set(gca, 'Ylim', [0, emax])
set(gca, 'XTick', []);
set(gca, 'XTickLabel', {});
ylabel('Density')
label(gca,  .55, .80, 'm=2');
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
set(gca, 'Ylim', [0, emax])
set(gca, 'XTick', []);
set(gca, 'XTickLabel', {});
ylabel('Density')
label(gca,  .55, .80, 'm=3');
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
set(gca, 'Ylim', [0, emax])
xlabel('Response Error')
ylabel('Density')
label(gca,  .55, .80, 'm=4');
hold
plot(thetad, pthetad, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% RT 1%
axes(axhandle(2));
histogram(Rt1, 50, 'Normalization', 'pdf', 'BinLimits', [0,rtmax]);
set(gca, 'Xlim', [0, rtmax])  
set(gca, 'Ylim', [0, rtdenmax])
set(gca, 'XTick', []);
set(gca, 'XTickLabel', {});
label(gca,  .55, .80, 'm=1');
hold
plot(ta, gtam, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor = cvec1;
c(2).Color = 'k';

% RT 2%
axes(axhandle(4));
histogram(Rt2, 50, 'Normalization', 'pdf', 'BinLimits', [0,rtmax]);
set(gca, 'Xlim', [0, rtmax]) 
set(gca, 'Ylim', [0, rtdenmax])
set(gca, 'XTick', []);
set(gca, 'XTickLabel', {});
label(gca,  .55, .80, 'm=2');
hold
plot(tb, gtbm, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';

% RT 3%
axes(axhandle(6));
histogram(Rt3, 50, 'Normalization', 'pdf', 'BinLimits', [0,rtmax]);
set(gca, 'Xlim', [0, rtmax])  
set(gca, 'XTick', []);
set(gca, 'XTickLabel', {});
set(gca, 'Ylim', [0, rtdenmax])
label(gca,  .55, .80, 'm=3');
hold
plot(tc, gtcm, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor = cvec1;
c(2).Color = 'k';

% RT 4%
axes(axhandle(8));
histogram(Rt4, 50, 'Normalization', 'pdf', 'BinLimits', [0,rtmax]);
set(gca, 'Xlim', [0, rtmax])  
xlabel('Response Time')
set(gca, 'Ylim', [0, rtdenmax])
label(gca, .55, .80, 'm=4');
hold
plot(td, gtdm, 'm-', 'Linewidth', 2);
c = get(gca, 'Child');
c(1).Color = cvec2;
c(3).FaceColor  = cvec1;
c(2).Color = 'k';





