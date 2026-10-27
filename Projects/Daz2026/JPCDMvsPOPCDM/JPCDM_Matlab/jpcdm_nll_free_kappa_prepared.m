function nll = jpcdm_nll_free_kappa_prepared(Q, dataByCond, condLevels, stFixed, tmax)
%=======================
% jpcdm_nll_free_kappa_prepared
%=======================
% Same model as jpcdm_nll_free_kappa, but uses pre-split numeric data.
%
% Q = [vnormBase, vnormNR, vnormR, eta, psi, a, ...
%      terC2, terC4, terC6, kappa_1, ..., kappa_9]

    penalty = 1e12;
    if any(~isfinite(Q))
        nll = penalty;
        return
    end

    nCond = numel(condLevels);
    if numel(Q) ~= 9 + nCond
        error('Q must have 9 + nCond values for the free-kappa model.');
    end

    vnormBase = Q(1);
    vnormNR = Q(2);
    vnormR = Q(3);
    eta = Q(4);
    psi = Q(5);
    a = Q(6);
    terGroups = Q(7:9);
    kappas = Q(10:end);

    baselineConds = ["S2C2NR", "S4C4NR", "S6C6NR"];
    nonredundantConds = ["S4C2NR", "S6C2NR", "S6C4NR"];
    redundantConds = ["S4C2R", "S6C2R", "S6C4R"];

    nll = 0;
    for c = 1:nCond
        dc = dataByCond{c};
        if isempty(dc.rt)
            continue
        end

        cond = condLevels(c);
        if ismember(cond, baselineConds)
            vnorm = vnormBase;
        elseif ismember(cond, nonredundantConds)
            vnorm = vnormNR;
        elseif ismember(cond, redundantConds)
            vnorm = vnormR;
        else
            error('Unexpected condition in vnorm mapping: %s', cond);
        end

        ter = map_color_ter(cond, terGroups);
        P = [vnorm, kappas(c), eta, psi, a, ter, stFixed];
        conditionNLL = jpcdm_nll_arrays(P, dc.rt, dc.rAngle, tmax);
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
