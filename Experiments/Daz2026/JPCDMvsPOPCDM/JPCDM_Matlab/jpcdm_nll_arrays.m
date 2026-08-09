function nll = jpcdm_nll_arrays(P, rt, rAngle, tmax)
%=======================
% jpcdm_nll_arrays
%=======================
% Fast NLL helper using numeric arrays instead of a data table.
% P = [vnorm, kappa, eta, psi, a, ter, st]
%
% Guardrails, normalization, interpolation, and likelihood floor match
% popcdm_nll_arrays so optimizer failures are handled consistently.

    penalty = 1e12;

    if numel(P) ~= 7 || any(~isfinite(P)) || ...
            any(~isfinite(rt)) || any(~isfinite(rAngle))
        nll = penalty;
        return
    end

    try
        [T, Gt, Theta] = jpcdm1(P, tmax);
    catch
        nll = penalty;
        return
    end

    ThetaOpen = Theta(1:end-1);
    GtOpen = Gt(1:end-1, :);

    if size(GtOpen, 1) ~= numel(ThetaOpen) || ...
            size(GtOpen, 2) ~= numel(T)
        nll = penalty;
        return
    end

    dtheta = ThetaOpen(2) - ThetaOpen(1);
    dt = T(2) - T(1);
    retainedTime = T>=0.3 & T<=3.0;
    if ~any(retainedTime)
        nll = penalty;
        return
    end

    GtOpen = max(GtOpen, 0);
    % The observed data were explicitly selected to 0.3--3.0 s. Condition
    % the model on that same selection interval; otherwise parameter sets
    % with probability beyond 3 s are penalized for unobserved trials.
    totalMass = sum(GtOpen(:,retainedTime), 'all') * dtheta * dt;
    if ~isfinite(totalMass) || totalMass <= 0
        nll = penalty;
        return
    end
    GtOpen = GtOpen / totalMass;

    like = interp2(T, ThetaOpen, GtOpen, rt, rAngle, 'linear', 1e-12);
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
