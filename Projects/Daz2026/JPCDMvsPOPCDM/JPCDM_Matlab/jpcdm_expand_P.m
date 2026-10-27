function condFit = jpcdm_expand_P(P, model)
%JPCDM_EXPAND_P Expand current JP H0 vector into condition rows.

    if numel(P) ~= model.nFree
        error('JPCDM:ParameterLength', 'Expected %d parameters.', model.nFree);
    end
    design = [2, 4, 4, 4, 6, 6, 6, 6, 6];
    vnorm = nan(model.nCond, 1);
    vnorm(design == 2) = P(model.index.vnorm(1));
    vnorm(design == 4) = P(model.index.vnorm(2));
    vnorm(design == 6) = P(model.index.vnorm(3));

    if model.name == "H0a"
        psi = P(model.index.front(:)).';
        kappa = repmat(P(model.index.sharedFront), model.nCond, 1);
    else
        kappa = P(model.index.front(:)).';
        psi = repmat(P(model.index.sharedFront), model.nCond, 1);
    end

    condFit = table(model.condLevels(:), vnorm, ...
        repmat(P(model.index.eta1), model.nCond, 1), ...
        repmat(model.eta2, model.nCond, 1), ...
        repmat(P(model.index.a), model.nCond, 1), kappa, psi, ...
        repmat(P(model.index.ter), model.nCond, 1), ...
        repmat(P(model.index.st), model.nCond, 1), ...
        'VariableNames', ...
        {'Cond','Vnorm','Eta1','Eta2','A','Kappa','Psi','Ter','St'});
end
