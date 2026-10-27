function nll = jpcdm_nll_free_kappa(Q, d, tmax, condLevels, stFixed)
%=======================
% jpcdm_nll_free_kappa
%=======================
% Q = [vnormBase, vnormNR, vnormR, eta, psi, a, ter, kappa_1, ..., kappa_9]
%
% vnormBase applies to S=C baseline conditions:
%   S2C2NR, S4C4NR, S6C6NR
% vnormNR applies to non-redundant cued conditions where S>C:
%   S4C2NR, S6C2NR, S6C4NR
% vnormR applies to redundant cued conditions:
%   S4C2R, S6C2R, S6C4R

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
        dc = d(d.condIdx == c, :);
        if isempty(dc)
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
        nll = nll + jpcdm_nll(P, dc, tmax);
    end
end
