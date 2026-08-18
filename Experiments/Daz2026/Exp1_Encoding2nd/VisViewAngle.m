%Visual Viewing Angle Calculation

 % stim 11.5mm = 1.1deg 
 % mask 14mm = 1.3deg
 % response wheel 88-100mm = 8.4 - 9.5deg
 % invisible radius 38mm = 3.6deg

S = 38;
D = 600;

theta_deg = 2 * atan( S./(2*D) ) * (180/pi);
