function [theta, thetacc, thetart] = thetaclass6(Data, nw, cond);
% =========================================================================================
% Classify RT and accuracy data by stimulus angle and condition. Medians
% nw is the number of theta bins. 
%       [theta, thetacc, thetart] = thetaclass6(Data, nw, cond);
% April 22 2020, modified <thetaclass4> for Elaine's motion data. 
% =========================================================================================
eps = 0.0001;
sz = size(Data);
if sz(2) ~= 4
   disp('Wrong size data matrix, returning...');
   return
end
thetax = 1;
response_errorx = 2;
rtx = 3;
szrt = 500; % (Arbitrary) buffer size
mq = 0.5;
thetabound = linspace(-pi, pi, nw+1);  % Bounds of theta bins - not really needed
theta = (thetabound(1:nw) + thetabound(2:nw+1))/2; % Centres of theta bins
szt = size(theta);
% Summary structures
thetacc = zeros(size(theta));
thetart = zeros(size(theta));
nacc = zeros(size(theta));
nrt = zeros(size(theta));  % Count the RTs
rt = zeros(szrt, length(theta));

% Pull out one condition.
%DataCond = Data(Data(:,condx) == cond,:);
DataCond = Data{cond};  % Structures are now cell arrays
szc = size(DataCond);
ld = szc(1)

for i = 1 : ld
     thetai = DataCond(i, thetax);  % Stimulus angle for trial i ###
     %thetai = Data(i, fixation_anglex); % Classify by response.
     %bin(thetai, nw)
     j = bin(thetai, nw) + (nw - 1)/ 2 + 1; % Bin index for the trial i stimulus
     %[thetai, i,j]  
     thetacc(j) = thetacc(j) + DataCond(i,response_errorx);
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
     else 
         thetart(j) = 0; 
     end
end


% end main


function j = bin(thetai, nw);   %========================================================================================
% Assign the stimulus angle to a bin. (Don't need the bin boundaries to do this.)
% =======================================================================================
  w = 2*pi/nw; % For Elaine's data nw = 18, w = .3491   
  j = ceil((thetai+eps) /(2*pi/nw));
  %j = ceil((thetai - w / 2) / nw);




