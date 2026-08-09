function nll = jpcdm_nll_arrays(P, rt, rAngle, tmax)
%=======================
% jpcdm_nll_arrays
%=======================
% Fast NLL helper using numeric arrays instead of a data table.
% P = [vnorm, kappa, eta, psi, a, ter, st]

    if any(~isfinite(P))
        nll = 1e12;
        return
    end

    [T, Gt, Theta] = jpcdm1(P, tmax);

    ThetaOpen = Theta(1:end-1);
    GtOpen = Gt(1:end-1, :);

    dtheta = ThetaOpen(2) - ThetaOpen(1);
    dt = T(2) - T(1);

    GtOpen = max(GtOpen, 0);
    totalMass = sum(GtOpen(:)) * dtheta * dt;
    if ~isfinite(totalMass) || totalMass <= 0
        nll = 1e12;
        return
    end
    GtOpen = GtOpen / totalMass;

    like = interp2(T, ThetaOpen, GtOpen, rt, rAngle, 'linear', 1e-12);
    like = max(like, 1e-12);

    if any(~isfinite(like))
        nll = 1e12;
        return
    end

    nll = -sum(log(like));
end
