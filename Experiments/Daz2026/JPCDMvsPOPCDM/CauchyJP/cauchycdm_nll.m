function nll = cauchycdm_nll(P, dataByCond, model, tmax)
%CAUCHYCDM_NLL Sum nine condition joint likelihoods.

    if numel(P) ~= model.nFree || any(~isfinite(P))
        nll = 1e12;
        return
    end
    vnormGroup = [1, 2, 2, 2, 3, 3, 3, 3, 3];
    vnorm = P(model.index.vnorm(vnormGroup));
    kappas = P(model.index.kappa);
    nll = 0;
    for c = 1:numel(dataByCond)
        dc = dataByCond{c};
        P7 = [vnorm(c), P(model.index.eta1), model.eta2, ...
            P(model.index.a), kappas(c), P(model.index.ter), ...
            P(model.index.st)];
        value = cauchycdm_nll_arrays(P7, dc.rt, dc.rAngle, tmax);
        if value >= 1e12
            nll = 1e12;
            return
        end
        nll = nll + value;
    end
end
