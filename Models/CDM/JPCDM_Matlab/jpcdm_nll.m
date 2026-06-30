function nll = jpcdm_nll(P, d, tmax)
%=======================
% jpcdm_nll basic fitting function
%=======================

% P = [vnorm, kappa, eta, psi, a, ter, st]
    if any(~isfinite(P))
        nll = 1e12;
        return
    end

    [T,Gt, Theta, Ptheta, Mt] = jpcdm1(P, tmax);

    ThetaOpen = Theta(1:end-1);
    GtOpen = Gt(1:end-1, :);

    dtheta = ThetaOpen(2) - ThetaOpen(1);
    dt = T(2) - T(1);

% Normalize density just in case numerical grid mass is not exactly 1
    GtOpen = max(GtOpen, 0);
    totalMass = sum(GtOpen(:)) * dtheta * dt;
    if ~isfinite(totalMass) || totalMass <= 0
        nll = 1e12;
        return
    end
    GtOpen = GtOpen / totalMass;

% Interpolate model density at observed data points
    like = interp2(T, ThetaOpen, GtOpen, d.rt, d.rAngle, 'linear', 1e-12);

% Avoid log(0)
    like = max(like, 1e-12);
    if any(~isfinite(like))
        nll = 1e12;
        return
    end

    nll = -sum(log(like));

end