function nll = popcdm_nll_free_alpha_prepared( ...
        Q, dataByCond, condLevels, eta2Fixed, stFixed, nw, h, tmax)
%POPCDM_NLL_FREE_ALPHA_PREPARED POPCDM 9a3v objective.
% Q = [vnormBase, vnormNR, vnormR, eta1, kappa, a, ...
%      terC2, terC4, terC6, ...
%      alpha_1, ..., alpha_9]
%
% This is the POPCDM counterpart of JPCDM 9p3v: the second parameter of
% the drift-angle distribution is condition-specific while the first is
% shared. POPCDM calls that condition-specific parameter alpha, hence 9a3v.

    penalty = 1e12;
    nCond = numel(condLevels);

    if numel(Q) ~= 9 + nCond
        error('Q must have 9 + nCond values for POPCDM 9a3v.');
    end
    if any(~isfinite(Q))
        nll = penalty;
        return
    end

    vnormBase = Q(1);
    vnormNR = Q(2);
    vnormR = Q(3);
    eta1 = Q(4);
    kappa = Q(5);
    a = Q(6);
    terGroups = Q(7:9);
    alphas = Q(10:end);

    nll = 0;
    for c = 1:nCond
        dc = dataByCond{c};
        if isempty(dc.rt)
            continue
        end

        vnorm = map_grouped_vnorm( ...
            condLevels(c), vnormBase, vnormNR, vnormR);
        ter = map_color_ter(condLevels(c), terGroups);
        P = [vnorm, eta1, eta2Fixed, a, alphas(c), kappa, ter, stFixed];

        conditionNLL = popcdm_nll_arrays( ...
            P, dc.rt, dc.rAngle, nw, h, tmax);
        if conditionNLL >= penalty
            nll = penalty;
            return
        end
        nll = nll + conditionNLL;
    end

    if ~isfinite(nll)
        nll = penalty;
    end
end

function ter = map_color_ter(cond, terGroups)
    if contains(cond, "C2")
        ter = terGroups(1);
    elseif contains(cond, "C4")
        ter = terGroups(2);
    elseif contains(cond, "C6")
        ter = terGroups(3);
    else
        error('Unexpected condition in ter mapping: %s', cond);
    end
end

function vnorm = map_grouped_vnorm(cond, vnormBase, vnormNR, vnormR)
    if ismember(cond, ["S2C2NR", "S4C4NR", "S6C6NR"])
        vnorm = vnormBase;
    elseif ismember(cond, ["S4C2NR", "S6C2NR", "S6C4NR"])
        vnorm = vnormNR;
    elseif ismember(cond, ["S4C2R", "S6C2R", "S6C4R"])
        vnorm = vnormR;
    else
        error('Unexpected condition in vnorm mapping: %s', cond);
    end
end
