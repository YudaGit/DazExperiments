function nll = popcdm_nll_arrays(P, rt, rAngle, nw, h, tmax)
%POPCDM_NLL_ARRAYS Negative log likelihood for one POPCDM condition.
%   P = [vnorm, eta1, eta2, a, alpha, kappa, ter, st]
%
% This intentionally follows the current JPCDM likelihood convention:
%   1. use 50 unique angular rows;
%   2. use the first 300 POPCDM time points, matching JPCDM's interior grid;
%   3. normalize the retained joint density numerically;
%   4. use linear interp2 interpolation and a 1e-12 likelihood floor.
%
% POPCDM returns 301 time points from 0 through tmax, whereas JPCDM returns
% 300 points from 0 through tmax-h. Dropping POPCDM's final column therefore
% gives both likelihoods the same time coordinates without modifying either
% forward model. This choice should be revisited when the grid convention is
% finalized for publication.

    penalty = 1e12;

    if numel(P) ~= 8 || any(~isfinite(P)) || ...
            any(~isfinite(rt)) || any(~isfinite(rAngle))
        nll = penalty;
        return
    end

    try
        [T, Gt, Theta] = popcdm2(P, nw, h, tmax);
    catch
        nll = penalty;
        return
    end

    % Match JPCDM's 50 x 300 likelihood grid. POPCDM's angle grid already
    % contains 50 unique points, so only its final time column is removed.
    TInterior = T(1:end-1);
    GtInterior = Gt(:, 1:end-1);

    if size(GtInterior, 1) ~= numel(Theta) || ...
            size(GtInterior, 2) ~= numel(TInterior)
        nll = penalty;
        return
    end

    dtheta = Theta(2) - Theta(1);
    dt = TInterior(2) - TInterior(1);
    retainedTime = TInterior>=0.3 & TInterior<=3.0;
    if ~any(retainedTime)
        nll = penalty;
        return
    end

    % Small negative values can arise from truncated numerical series.
    GtInterior = max(GtInterior, 0);
    % Match the 0.3--3.0 s selection applied to the behavioral data.
    totalMass = sum(GtInterior(:,retainedTime), 'all') * dtheta * dt;
    if ~isfinite(totalMass) || totalMass <= 0
        nll = penalty;
        return
    end
    GtInterior = GtInterior / totalMass;

    % Keep the interpolation rule identical to the fitted JPCDM scripts.
    % The angular grid is currently open at +pi; a future harmonized
    % likelihood should periodically close both models in the same way.
    like = interp2(TInterior, Theta, GtInterior, ...
        rt, rAngle, 'linear', 1e-12);
    like = max(like, 1e-12);

    if any(~isfinite(like))
        nll = penalty;
        return
    end

    nll = -sum(log(like));
    if ~isfinite(nll)
        nll = penalty;
    end
end
