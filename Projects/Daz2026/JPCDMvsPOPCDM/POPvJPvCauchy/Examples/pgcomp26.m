function pgcomp26(Data, Pred1, Pred2, ymax)
% ========================================================================
% Plot fitted values of circular diffusion model with drift variability
% for multirange relication. 
% 09/08/26
%     pgcomp26(Data, Pred1, Pred2, {[emax, rtmax]})
% ========================================================================

disp('Second Pred is dashed...')
% Take cell structure as argument
Preds1 = Pred1{1,1}; 
Preds2 = Pred2{1,1}; 

Gstuff1 = Pred1{2,1}; % third row is Precision, CSD
Gstuff2 = Pred2{2,1}; % third row is Precision, CSD

if nargin < 4
   emax = 1.5;
   rtmax = 2.5;
else
   emax = ymax(1);
   rtmax = ymax(2);   
end


SetLab = {'m=1'; 'm=2'; 'm=4'; 'm=6'};
SatLab = {'S^-';'S^+'};

cvec1 = [.90, .95, .95];   % Kinda blue...
cvec2 = [.60, 0, .60]; % Dark magenta
cvec3 = [0.3, .60, .30]; %

ymax = 4.0; % Hard-wired 

name = 'MWM24: ';
errmg1 = 'Data should be a 1 x 4 cell array...';

nset = 4;
if any(size(Data) ~= [1,nset])
   disp('Wrong size data matrix, exiting...')
   return
end


% Accuracy
Ax = [1,3,5,7];
Rx = [2,4,6,8]
axhandle = setfig8;
    for j = 1:nset
         Thetaij = Data{j}(:,2);
         thetaij = Preds1{2,j}(1,:);
         pthetaij1 = Preds1{2,j}(2,:);
         pthetaij2 = Preds2{2,j}(2,:);
         % Columns are saturation, rows are set size
         axno = Ax(j); % 2 * (j - 1) + j        
         axes(axhandle(axno))
         histogram(Thetaij, 50, 'Normalization', 'pdf', 'BinLimits', [-pi,pi]);
         set(gca, 'Xlim', [-pi, pi])
         set(gca, 'Ylim', [0, emax])
         if axno == 7
             xlabel('Response Error')
         end
         if axno == 1 | axno == 3 || axno == 5 || axno == 7
             ylabel('Density')
         end
         if axno < 7
             xticklabels({})
         end        
         label(gca,  .60, .85, SetLab{j});
         hold
         plot(thetaij, pthetaij1, '-', 'Linewidth', 2);
         plot(thetaij, pthetaij2, '--', 'Linewidth', 2);
         c = get(gca, 'Child')
         c(1).Color = cvec2;
         c(2).Color = cvec3;
         %c(5).FaceColor  = cvec1;
         c(3).Color = 'k';
 
         % Response times
         RTij = Data{j}(:,3);
         tij1 = Preds1{1,j}(1,:);
         tij2 = Preds2{1,j}(1,:);
         gtij1 = Preds1{1,j}(2,:); 
         gtij2 = Preds2{1,j}(2,:); 
        % Columns are saturation, rows are set size
         axno = Rx(j); %  )2 * j;        
         axes(axhandle(axno))
         histogram(RTij, 50, 'Normalization', 'pdf', 'BinLimits', [0,rtmax]);
         set(gca, 'Xlim', [0, rtmax])
         if axno == 8     
             xlabel('Response Time')
         end 
         if axno < 7
             xticklabels({})
         end     
         set(gca, 'Ylim', [0, ymax])
         label(gca,  .60, .85, SetLab{j});
         hold
         plot(tij1, gtij1, '-', 'Linewidth', 2);
         plot(tij2, gtij2, '--', 'Linewidth', 2);
         c = get(gca, 'Child');
         c(1).Color = cvec2;
         c(2).Color = cvec3;         
         %c(5).FaceColor = cvec1;
         c(3).Color = 'k';
    end
end    



