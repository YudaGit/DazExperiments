function nll = jpcdm_nll_free_kappa_prepared(Q, dataByCond, condLevels, stFixed, tmax)
%=======================
% jpcdm_nll_free_kappa_prepared
%=======================
% Same model as jpcdm_nll_free_kappa, but uses pre-split numeric data.
%
% Q = [vnormBase, vnormNR, vnormR, eta, psi, a, ter, kappa_1, ..., kappa_9]

    if any(~isfinite(Q))
        nll = 1e12;
        return
    end

    nCond = numel(condLevels);
    if numel(Q) ~= 7 + nCond
        error('Q must have 7 + nCond values for the free-kappa model.');
    end

    vnormBase = Q(1);
    vnormNR = Q(2);
    vnormR = Q(3);
    eta = Q(4);
    psi = Q(5);
    a = Q(6);
    ter = Q(7);
    kappas = Q(8:end);

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

        P = [vnorm, kappas(c), eta, psi, a, ter, stFixed];
        nll = nll + jpcdm_nll_arrays(P, dc.rt, dc.rAngle, tmax);
    end
end
