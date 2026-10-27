function nll = cauchycdm_nll_arrays(P, rt, rAngle, tmax)
%CAUCHYCDM_NLL_ARRAYS Joint RT-angle NLL for one Cauchy-CDM condition.
% P = [vnorm, eta1, eta2, a, kappa, ter, st]

    penalty = 1e12;
    if numel(P) ~= 7 || any(~isfinite(P)) || ...
            any(~isfinite(rt)) || any(~isfinite(rAngle))
        nll = penalty;
        return
    end
    try
        [T, Gt, Theta] = cauchycdm2(P, tmax);
    catch
        nll = penalty;
        return
    end
    Gt = max(Gt, 0);
    dtheta = Theta(2) - Theta(1);
    dt = T(2) - T(1);
    keep = T >= 0.3 & T <= 3.0;
    totalMass = sum(Gt(:, keep), 'all') * dtheta * dt;
    if ~(isfinite(totalMass) && totalMass > 0)
        nll = penalty;
        return
    end
    Gt = Gt / totalMass;

    % Periodically close the angular grid before interpolation.
    thetaClosed = [Theta, pi];
    gtClosed = [Gt; Gt(1, :)];
    like = interp2(T, thetaClosed, gtClosed, rt, rAngle, 'linear', 1e-12);
    like = max(like, 1e-12);
    if any(~isfinite(like))
        nll = penalty;
        return
    end
    nll = -sum(log(like));
end
