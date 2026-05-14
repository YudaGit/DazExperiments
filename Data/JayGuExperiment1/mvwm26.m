function mvw24(Data, Pred, ymax)
% ========================================================================
% Plot fitted values of circular diffusion model with drift variability
% to Allen Qian's Small-N experiment (2 saturation x 3 set size (1,2,4,6))
% Now has multidimensional cell arrays as argument
% 17/6/24
%     mvw24Data, Pred, {[emax, rtmax]})
% ========================================================================

% Take cell structure as argument
Preds = Pred{1,1}; 
Gstuff = Pred{2,1}; % third row is Precision, CSD



if nargin < 3
   emax = 1.5;
   rtmax = 2.5;
else
   emax = ymax(1);
   rtmax = ymax(2);   
end


SetLab = {'m=1'; 'm=2'; 'm=4'; 'm=6'};
SatLab = {'S^-';'S^+'};

cvec2 = [.60, 0, .60]; % Dark magenta
cvec1 = [.90, .95, .95];   % Kinda blue..

ymax = 4.0; % Hard-wired 

name = 'MWM24: ';
errmg1 = 'Data should be a 1 x 4 cell array...';

nsat = 2;
nset = 4;
if any(size(Data) ~= [nsat,nset])
   disp('Wrong size data matrix, exiting...')
   return
end


% Accuracy
axhandle1 = setfig8; % setfig8narrow;
for i = 1:nsat
    for j = 1:nset
         Thetaij = Data{i,j}(:,2);
         thetaij = Preds{2,i,j}(1,:);
         pthetaij = Preds{2,i,j}(2,:);
         % Columns are saturation, rows are set size
         axno = nsat * (j - 1) + i;        
         axes(axhandle1(axno))
         histogram(Thetaij, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
         set(gca, 'Xlim', [-pi, pi])
         set(gca, 'Ylim', [0, emax])
         if axno == 7 | axno == 8
             xlabel('Response Error')
         end
         if axno == 1 | axno == 3 || axno == 5 || axno == 7
             ylabel('Density')
         end
         if axno < 7
             xticklabels({})
         end        
         label(gca,  .60, .85, SetLab{j});
         label(gca,  .60, .70, SatLab{i});
         hold
         plot(thetaij, pthetaij, 'm-', 'Linewidth', 2);
         c = get(gca, 'Child');
         c(1).Color = cvec2;
         c(4).FaceColor  = cvec1;
         c(2).Color = 'k';
    end
end

% RT
axhandle2 = setfig8; % narrow;
for i = 1:nsat
    for j = 1:nset
         RTij = Data{i,j}(:,3);
         tij = Preds{1,i,j}(1,:);
         gtij = Preds{1,i,j}(2,:); 
        % Columns are saturation, rows are set size
         axno = nsat * (j - 1) + i;
         axes(axhandle2(axno))
         histogram(RTij, 50, 'Normalization', 'pdf', 'BinLimits', [0,rtmax]);
         set(gca, 'Xlim', [0, rtmax])
         if axno == 1 | axno == 3 | axno == 5 | axno == 7 
              ylabel('Density')
         end
         if axno == 7 | axno == 8     
             xlabel('Response Time')
         end 
         if axno < 7
             xticklabels({})
         end     
         set(gca, 'Ylim', [0, ymax])
         label(gca,  .60, .85, SetLab{j});
         label(gca,  .60, .70, SatLab{i});
         hold
         plot(tij, gtij, 'm-', 'Linewidth', 2);
         c = get(gca, 'Child');
         c(1).Color = cvec2;
         c(4).FaceColor = cvec1;
         c(2).Color = 'k';
    end
end    



