function nll = popcdm_nll_theory(Pvar, Pfix, Sel, dataByCond, meta)
%POPCDM_NLL_THEORY Negative log-likelihood for theory hypotheses.
% Example Fitting Package calling convention:
%   nll = popcdm_nll_theory(Pvar, Pfix, Sel, dataByCond, meta)
%
% meta fields: hyp, catalog (from pop_theory_models), nw, h, tmax

    penalty = 1e12;

    if numel(Pvar) ~= sum(Sel) || numel(Pfix) ~= sum(~Sel)
        nll = penalty;
        return
    end
    if any(~isfinite(Pvar)) || any(~isfinite(Pfix))
        nll = penalty;
        return
    end

    P = zeros(1, numel(Sel));
    P(Sel) = Pvar;
    P(~Sel) = Pfix;

    try
        condFit = pop_theory_expand_P(P, meta.hyp, meta.catalog);
    catch
        nll = penalty;
        return
    end

    nll = 0;
    nCond = height(condFit);
    for c = 1:nCond
        dc = dataByCond{c};
        if isempty(dc.rt)
            continue
        end
        P8 = [condFit.Vnorm(c), condFit.Eta1(c), condFit.Eta2(c), ...
              condFit.A(c), condFit.Alpha(c), condFit.Kappa(c), ...
              condFit.Ter(c), condFit.St(c)];
        conditionNLL = popcdm_nll_arrays( ...
            P8, dc.rt, dc.rAngle, meta.nw, meta.h, meta.tmax);
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
