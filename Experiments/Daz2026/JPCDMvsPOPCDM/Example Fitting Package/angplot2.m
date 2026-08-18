function angplot2(Raw, Pred, ymax)
% ====================================================================================
% Plot the marginal median error and median RT as a function of stimulus angle.
% for Experiment 2
%     angplot2(Raw, Pred, {[ymaxac, ymaxrt]})  
% ====================================================================================
    ne = 18;
    bscale = 1.0; % 0.3491 / 0.1257;
    co = [0,0,1; 
         0,0.5,0;
         1,0,0;
         0,0.75,0.75;
         0.75,0,0.75;
         0.75,0.75,0;
         0.25,0.25,0.25];

  set(groot,'defaultAxesColorOrder',co);

   err1 = 'ANGPLOT2: Wrong size raw data';
   err2 = 'ANGPLOT2: Wrong size Pred';
   c = 0.50;
   cvec1 = [.90, .95, .95];   % Kinda blue...
   cvec2 = [.60, 0, .60];   % Dark magenta
   mdx = 4; % Row index of median in data structure
   szr = size(Raw)
   if szr(2) ~= 4
      err1
      return
   end
   if ~(all(size(Pred) == [3,2]) || all(size(Pred) == [3,4])) % changed from 2 to 4
      err2 
      return
   end
   if nargin < 3
     ymax = 2.0;
   end
   axhandle = setfig42x;
   [theta1,thetacc1,thetart1]=thetaclass6(Raw, ne+1, 1);  
   axes(axhandle(1));
   bar(theta1, thetacc1)
   hold
   plot(Pred{3,1}(1,:), bscale * Pred{3,1}(2,:), 'm-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [-1.0,1.0])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('Mean Error (rad)');
   label(gca, .1, .9, '50%')

   axes(axhandle(2));
   bar(theta1, thetart1 - c)
   hold
   plot(Pred{3,1}(1,:), Pred{3,1}(mdx,:) - c, '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [0,ymax])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('MdRT - 0.5')
   label(gca, .1, .9, '50%')

   [theta2,thetacc2,thetart2]=thetaclass6(Raw, ne+1, 2);
   axes(axhandle(3));
   bar(theta2, thetacc2)
   hold
   plot(Pred{3,2}(1,:), bscale * Pred{3,2}(2,:), '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [-1.0,1.0])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('Mean Error (rad)');
   label(gca, .1, .9, '25%')

   axes(axhandle(4));
   bar(theta2, thetart2 - c)
   hold
   plot(Pred{3,2}(1,:), Pred{3,2}(mdx,:) - c, '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [0,ymax])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('MdRT - 0.5')
   label(gca, .1, .9, '25%')


