function nll = jpcdm_nll_free_psi_prepared(Q, dataByCond, condLevels, stFixed, tmax)
%=======================
% jpcdm_nll_free_psi_prepared
%=======================
% Q = [vnormBase, vnormNR, vnormR, eta, kappa, a, ter, psi_1, ..., psi_9]

    if any(~isfinite(Q))
        nll = 1e12;
        return
    end

    nCond = numel(condLevels);
    if numel(Q) ~= 7 + nCond
        error('Q must have 7 + nCond values for the free-psi model.');
    end

    vnormBase = Q(1);
    vnormNR = Q(2);
    vnormR = Q(3);
    eta = Q(4);
    kappa = Q(5);
    a = Q(6);
    ter = Q(7);
    psis = Q(8:end);

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

        P = [vnorm, kappa, eta, psis(c), a, ter, stFixed];
        nll = nll + jpcdm_nll_arrays(P, dc.rt, dc.rAngle, tmax);
    end
end
