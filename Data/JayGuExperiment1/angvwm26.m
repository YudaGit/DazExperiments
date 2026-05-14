function angvwm24(Data, Pred, ymax)
% ====================================================================================
% Plot the marginal median error and median RT as a function of stimulus angle
% in wheel-relative rotated coordinates for Allen Qian's desaturated experiment
% 17/6/24
%     angvwmw24(Data, Pred, {[ymaxac, ymaxrt]}) 
% ====================================================================================


   %-------------------
    Preds = Pred{1,1};
    Gstuff = Pred{2,1};
   %-------------------- 
    ne = 50;
    bscale = 1.0; % 0.3491 / 0.1257;
    co = [0,0,1; 
         0,0.5,0;
         1,0,0;
         0,0.75,0.75;
         0.75,0,0.75;
         0.75,0.75,0;
         0.25,0.25,0.25];

   set(groot,'defaultAxesColorOrder',co);

   err1 = 'ANGVWM24 Wrong size Data data';
   err2 = 'ANGVWM24: Wrong size Preds';

   mdx = 4; % Row index of median in data structure
   nsat = 2;
   nset = 4;   
   if any(size(Data) ~= [nsat,nset])
      disp('Wrong size data matrix, exiting...')
      return
   end  
 
   if nargin < 3
      ymaxac = 1.0;
      ymaxrt = 2.0;
   else
      if ~all(size(ymax == [1,2]))
          disp('Wrong size ymax vector, exiting...');
          return
      end
      ymaxac = ymax(1);
      ymaxrt = ymax(2);      
   end
   
   SetLab = {'n=1'; 'n=2'; 'n=4'; 'n=6'};
   SatLab = {'Low';'High'};
   cvec1 = [.90, .95, .95];   % Kinda blue...
   cvec2 = [.60, 0, .60];   % Dark magenta   
   
   yminrt = 0.2; % Hack for Q1 plot

   axhandle1 = setfig8;
   for i = 1:nsat
       for j = 1:nset
           [thetaij,thetaccij,thetartij]=thetaclass6rot(Data, ne, i, j);
           axno = nsat * (j - 1) + i;        
           axes(axhandle1(axno))
           bar(thetaij, thetaccij)
           hold
           plot(Preds{3,i,j}(1,:), bscale * Preds{3,i,j}(2,:), 'm-', 'Linewidth', 2)
           ch = get(gca, 'Child');
           ch(2).FaceColor = cvec1;
           ch(1).Color = cvec2;
           set(gca, 'YLim', [-ymaxac,ymaxac])
           set(gca, 'XLim', [-pi,pi])
           if axno == 7 | axno == 8           
               xlabel('Stimulus angle (rad)')
           end 
           if i == 1   
               ylabel('Mean Error (rad)');
           end    
           label(gca,  .35, .85, SetLab{j});
           label(gca,  .65, .85, SatLab{i});
       end
   end           
       
   axhandle2 = setfig8;
   for i = 1:nsat
       for j = 1:nset
           % Have to call this a second time to get the RT stuff
           [thetaij,thetaccij,thetartij]=thetaclass6rot(Data, ne, i, j);
           axno = nsat * (j - 1) + i; 
           axes(axhandle2(axno))       
           bar(thetaij, thetartij)
           hold
           plot(Preds{3,i,j}(1,:), Preds{3,i,j}(mdx,:), '-', 'Linewidth', 2)
           ch = get(gca, 'Child');
           ch(2).FaceColor = cvec1;
           ch(1).Color = cvec2;
           set(gca, 'YLim', [yminrt,ymaxrt])
           set(gca, 'XLim', [-pi,pi])
           if axno == 7 | axno == 8           
              xlabel('Stimulus angle (rad)')
           end
           if i == 1
               ylabel('Median RT (s)')
           end       
           label(gca,  .35, .85, SetLab{j});
           label(gca,  .65, .85, SatLab{i});         
      end
   end         
end

function [theta, thetacc, thetart] = thetaclass6rot(Data, nw, sati, setj);
% =========================================================================================
% Classify RT and accuracy data by stimulus angle in wheel-relative coordinates and condition. 
%nw is the number of theta bins. 
%       [theta, thetacc, thetart, thetartq1] = thetaclass6(Data, nw, sat, set);
% April 22 2020, modified <thetaclass4> for Elaine's motion data. 
% Dec 4, 2022, deleted the Q1 calculation because of empty data.
% =========================================================================================
eps = 0.0001;
sz = size(Data);
% This is the number of conditions, not the number of columns.
if sz ~= [2,4];
   disp('Wrong size data matrix, returning...');
   return
end
thetax = 1;
response_errorx = 2;
rtx = 3;
szrt = 1000; % (Arbitrary) buffer size
mq = 0.5;
thetabound = linspace(-pi, pi, nw+1);  % Bounds of theta bins - not really needed
theta = (thetabound(1:nw) + thetabound(2:nw+1))/2; % Centres of theta bins
szt = size(theta);
% Summary structures
thetacc = zeros(size(theta));
thetart = zeros(size(theta));
nacc = zeros(size(theta));
nrt = zeros(size(theta));  % Count the RTs
nrtq1 = zeros(size(theta)); % Count RTs for Q1 (12/09/22) 
rt = zeros(szrt, length(theta));

DataCond = Data{sati,setj};  % Pull out the individual condition
szc = size(DataCond);
ld = szc(1);

for i = 1 : ld
     thetai = DataCond(i, thetax);  % Stimulus angle for trial i ###
     %thetai = Data(i, fixation_anglex); % Classify by response.
     %bin(thetai, nw)
     %%%%j = bin(thetai, nw) + (nw - 1)/ 2 + 1 % Bin index for the trial i stimulus
     j = bin(thetai, nw) + nw / 2;
     thetacc(j) = thetacc(j) + DataCond(i,response_errorx);
     %[thetai, i,j, DataCond(i,response_errorx), thetacc(j), nacc(j)] 
     nacc(j) = nacc(j) + 1; 
     rt(nrt(j) + 1, j) = DataCond(i, rtx);
     thetart(j) = thetart(j) + DataCond(i, rtx);
     nrt(j) = nrt(j) + 1;
end

% Accuracy
for j = 1:length(theta)
    if nacc(j) > 0 
        thetacc(j) = thetacc(j) / nacc(j);
    else
        thetacc(j) = 0;
    end
end
% RT
for j = 1:length(theta)
     rtj = sort(rt(1:nrt(j), j));
     if nrt(j) > 1  % Allow for empty bins.
         if ~mod(nrt(j), 2) % Even
             thetart(j) = (rtj(nrt(j) / 2) + rtj(nrt(j) / 2 + 1)) / 2;
         else % Odd
             thetart(j) = rtj(floor(nrt(j) / 2) + 1);
         end
         % Do Q1 (12/09/22)
        % nrt(j)
        % q1x = round(0.1 * nrt(j)) 
        % thetartq1(j) = rtj(q1x);  
     else 
         thetart(j) = 0; 
         thetartq1(j) = 0;
     end
     
end
end

% end main


function j = bin(thetai, nw);   
%========================================================================================
% Assign the stimulus angle to a bin. (Don't need the bin boundaries to do this.)
% =======================================================================================
  w = 2*pi/nw; % For Elaine's data nw = 18, w = .3491   
  j = ceil((thetai+eps) /(2*pi/nw));
  %j = ceil((thetai - w / 2) / nw);
end





