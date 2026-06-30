function [T,Gt, Theta, Ptheta, Mt] = jpcdm1(P, tmax)
% =======================================================================
% CDM with Jones-Pewsey polar angle of drift rate
%    [T,Gt, Theta, Ptheta, Mt] = jpcdm1(P, tmax)
% nw=50 and h=tmax/300 hard-wired in vjp300rot. Need to change 
% manually, #define nw 50 #define sz 300 in ll. 20-22 of C-code
% if you want different values, and re-mex. 
%    P = [vnorm, kappa, eta, psi,  a, ter, st]
%    eta1 = eta; eta2 = 0.01 in C code. The JP distribution
% is generated in C in vjp300rot and integrated across. kappa is JP
% precision, psi is JP shape, phi is JP centre forced to 0 (canonical
% orientation)
%  =======================================================================
    if length(P) ~= 7
       disp('JPCMD1: Wrong length parameter vector, exiting...')
       length(P)
       return
    end 
    nw = 50; % This has to be consistent with l. 20 of C-code
    sz = 300; % This has to be consistent with l. 22 of C-code
    h = tmax / sz;
    vnorm = P(1); 
    kappa = P(2);
    eta = P(3);
    psi = P(4);
    a = P(5);
    ter = P(6);
    st = P(7);
    sigma = 1.0; % hard wired;
    phi = 0; % JP centre, canonical orientation
    yfloor = 1e-9;
    [T, Gta, Theta, Ptheta, Mta] = vjp300rot([vnorm, kappa, eta, phi, psi, sigma, a], tmax, yfloor);
    Gt = zeros(size(Gta));  

    % Add nondecision times
    T = T + ter + st / 2;
    % --------------------
    % Convolve with Ter.
    % --------------------
    if st > 2 * h
       m = round(st / h);
       n = length(T);
       fe = ones(1, m) / m; % Uniform distribution of nondecision times 
       for i = 1 : nw
            Gti = conv(Gta(i,:), fe);
            Gt(i,:) = Gti(1:sz); % truncate extra values from convolution
       end     
       Mt = Mta + ter + st / 2;      
    else
       Gt = Gta; % negligible nondecision time
       Mt = Mta + ter;
   end         
end       
       
