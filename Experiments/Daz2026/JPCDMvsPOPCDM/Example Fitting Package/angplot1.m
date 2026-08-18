function angplot1(Raw, Pred, ymax)
% ====================================================================================
% Plot the marginal median error and median RT as a function of stimulus angle.
% for Experiment 1
%     angplot1(Raw, Pred, {[ymaxac, ymaxrt]}) 
% ====================================================================================
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

   err1 = 'ANGPLOT1: Wrong size raw data';
   err2 = 'ANGPLOT1: Wrong size Pred';
   c = 0;
   cvec1 = [.90, .95, .95];   % Kinda blue...
   cvec2 = [.60, 0, .60];   % Dark magenta
   mdx = 4; % Row index of median in data structure
   szr = size(Raw);
   if szr(2) ~= 4
      err1
      return
   end
   if ~all(size(Pred) == [3,4])
      err2 
      return
   end
   if nargin < 3
      ymaxac = 1.0;
      ymaxrt = 1.5;
   else
      if ~all(size(ymax == [1,2]))
          disp('Wrong size ymax vector, exiting...');
          return
      end
      ymaxac = ymax(1);
      ymaxrt = ymax(2);      
   end
   axhandle = setfig8;
  % axhandle = setfig8hh;

   [theta1,thetacc1,thetart1]=thetaclass8(Raw, ne, 1);
   axes(axhandle(1));
   bar(theta1, thetacc1)
   hold
   plot(Pred{3,1}(1,:), bscale * Pred{3,1}(2,:), 'm-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [-ymaxac,ymaxac])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('Mean Error (rad)');
   label(gca, .1, .9, '23 ms')

   axes(axhandle(2));
   bar(theta1, thetart1 - c)
   hold
   plot(Pred{3,1}(1,:), Pred{3,1}(mdx,:) - c, '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [0,ymaxrt])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('MdRT')
   label(gca, .1, .9, '23 ms')


   [theta2,thetacc2,thetart2]=thetaclass8(Raw, ne, 2);
   axes(axhandle(3));
   bar(theta2, thetacc2)
   hold
   plot(Pred{3,2}(1,:), bscale * Pred{3,2}(2,:), '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [-ymaxac,ymaxac])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('Mean Error (rad)');
   label(gca, .1, .9, '47 ms')

   axes(axhandle(4));
   bar(theta2, thetart2 - c)
   hold
   plot(Pred{3,2}(1,:), Pred{3,2}(mdx,:) - c, '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [0,ymaxrt])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('MdRT')
   label(gca, .1, .9, '47 ms')

   [theta3,thetacc3,thetart3]=thetaclass8(Raw, ne, 3);
   axes(axhandle(5));
   bar(theta3, thetacc3)
   hold
   plot(Pred{3,3}(1,:), bscale * Pred{3,3}(2,:), 'm-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [-ymaxac,ymaxac])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('Mean Error (rad)');
   label(gca, .1, .9, '70 ms')

   axes(axhandle(6));
   bar(theta3, thetart3 - c)
   hold
   plot(Pred{3,3}(1,:), Pred{3,1}(mdx,:) - c, '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [0,ymaxrt])
   set(gca, 'XLim', [-pi,pi])                                                                                                 
   xlabel('Stimulus angle (rad)')
   ylabel('MdRT')
   label(gca, .1, .9, '70 ms')


   [theta4,thetacc4,thetart4]=thetaclass8(Raw, ne, 4);
   axes(axhandle(7));
   bar(theta4, thetacc4)
   hold
   plot(Pred{3,4}(1,:), bscale * Pred{3,4}(2,:), '-', 'Linewidth', 2)
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [-1.0,1.0])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('Mean Error (rad)');
   label(gca, .1, .9, '94 ms')

   axes(axhandle(8));
   bar(theta4, thetart4 - c)
   hold
   plot(Pred{3,4}(1,:), Pred{3,4}(mdx,:) - c, '-', 'Linewidth', 2)                                                                                                                                                    
   ch = get(gca, 'Child');
   ch(2).FaceColor = cvec1;
   ch(1).Color = cvec2;
   set(gca, 'YLim', [0,ymaxrt])
   set(gca, 'XLim', [-pi,pi])
   xlabel('Stimulus angle (rad)')
   ylabel('MdRT')
   label(gca, .1, .9, '94 ms')

