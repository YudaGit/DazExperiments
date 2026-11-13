function nll = jpcdm_nll(P, dataByCond, model, tmax)
%JPCDM_NLL Sum nine-condition JP-CDM joint likelihoods.

    if numel(P) ~= model.nFree || any(~isfinite(P))
        nll = 1e12;
        return
    end
    vnormGroup = [1, 2, 2, 2, 3, 3, 3, 3, 3];
    vnorm = P(model.index.vnorm(vnormGroup));
    front = P(model.index.front);
    sharedFront = P(model.index.sharedFront);
    nll = 0;
    for c = 1:numel(dataByCond)
        dc = dataByCond{c};
        if model.name == "H0a"
            kappa = sharedFront;
            psi = front(c);
        else
            kappa = front(c);
            psi = sharedFront;
        end
        P8 = [vnorm(c), kappa, P(model.index.eta1), model.eta2, ...
            psi, P(model.index.a), P(model.index.ter), P(model.index.st)];
        value = jpcdm_nll_arrays(P8, dc.rt, dc.rAngle, tmax);
        if value >= 1e12
            nll = 1e12;
            return
        end
        nll = nll + value;
    end
end
