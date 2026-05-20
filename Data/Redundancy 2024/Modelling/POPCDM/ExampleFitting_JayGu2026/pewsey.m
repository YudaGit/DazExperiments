function [th, pth, J] = pewsey(P, h);
% ============================================================================
% Jones-Pewsey circular distribution
%   [th, pth, J] = pewsey(P, h); their equation 2.
%    P = [kappa, psi]
% (normalization the same for positive and negative Psi, see their comment)
% on p. 1423
% ============================================================================
    kappa = P(1);
    psi = P(2);
    th = [-pi:h:pi];
    th0 = [0:h:pi]; % half circle for integration
    eps = 1e-9;
    if psi == 0 
       psi = eps;
    end
    v = 1 / psi; %J&P notation
    kp = kappa * psi;
    pth = (cosh(kp) + sinh(kp) * cos(th)).^v;
    mass = sum(pth)*h;
    %pth = pth / mass;

    % analytic mass, p. 1423, associated Legendre as a function of gamma and hypegeometric (A &S S, 8.1.2)
    z = cosh(kp);
    zprod = (z + 1)/(z - 1);
    hyp0 = hypergeom([-v, v+1], 1, (1-z) / 2); % mu = 0 same as hyp2 
    Pv0 = zprod^0 / gamma(1) * hyp0;
    amass = 2 * pi * Pv0;
    pth = pth / amass; % Uses analytic rather than numerical mass 
    % analytic CSD
    hyp1 = hypergeom([-v, v+1], 2, (1-z) / 2); % mu = -1 
    hyp2 = hypergeom([-v, v+1], 1, (1-z) / 2); % mu = 0
    sc1 = zprod^(-1)/2 /gamma(2);
    sc2 = zprod^0 / gamma(1);
    num = sc1 * hyp1;
    den = sc2 * hyp2;
    alpha1 = abs(psi)/(1 + psi) * num / den;
    csd = sqrt(-2 * log(alpha1))
    %numcsd = sqrt((sum(cos(th) .* pth) * h)^2 + (sum(sin(th) .* pth) * h)^2) - same 
    numcsd = (sum(cos(th) .* pth) * h)
    invscsd = 1 / csd;
    invnumcsdm = 1 /numcsd
    %trigcsd = gamma(v + 1) * num / (gamma(v + 2) * den) -   p. 1424 - doesn't match anything

    % Fisher information - this is i_kk, want i_mu_mu!
    qv = sum((cosh(kp) + sinh(kp) * cos(th0)).^v) * h;  % p. 1425
    rv = sum((cosh(kp) + sinh(kp) * cos(th0)).^(v-1) .* (sinh(kp) + cosh(kp) * cos(th0))) * h;   
    varth = sum(pth .* th.^2) * h;
    naive_sd = sqrt(varth)   
    J =  v * sinh(kp) * rv / qv
end   

% These are the calculations for i_K_k
    %aqv1 = (cosh(kp) + sinh(kp) * cos(th0)).^(v-1) .* (1 + coth(kp) * cos(th0));
    %qvprime = v * sum(aqv1) * h;
    %aqv2a = (cosh(kp) + sinh(kp) * cos(th0)).^(v-2) .* (1 + coth(kp) * cos(th0)).^2;
    %aqv2b = (cosh(kp) + sinh(kp) * cos(th0)).^(v-1) .* cos(th0);
    %qvprime2 = v * (v - 1) * sum(aqv2a) * h ...
    %         - v * sinh(kp).^(-3) * sum(aqv2b) * h; 
    %asv = (cosh(kp) + sinh(kp) * cos(th0)).^(v-2) .* (1 - cos(th0).^2);
    %sv = sum(asv) * h;
    %J = - psi * sv / qv + psi^2 * (cosh(kp) * qvprime / qv + sinh(kp)^2 * (qvprime2 / qv - qvprime^2/qv^2));



