function condFit = cauchycdm_expand_P(P, model)
%CAUCHYCDM_EXPAND_P Expand H0 vector into nine condition parameter rows.

    if numel(P) ~= model.nFree
        error('CauchyCDM:ParameterLength', 'Expected %d parameters.', model.nFree);
    end
    design = [2, 4, 4, 4, 6, 6, 6, 6, 6];
    vnorm = nan(9, 1);
    vnorm(design == 2) = P(model.index.vnorm(1));
    vnorm(design == 4) = P(model.index.vnorm(2));
    vnorm(design == 6) = P(model.index.vnorm(3));
    condFit = table(model.condLevels(:), vnorm, ...
        repmat(P(model.index.eta1), 9, 1), repmat(model.eta2, 9, 1), ...
        repmat(P(model.index.a), 9, 1), P(model.index.kappa(:)).', ...
        repmat(P(model.index.ter), 9, 1), repmat(P(model.index.st), 9, 1), ...
        repmat(model.psi, 9, 1), 'VariableNames', ...
        {'Cond','Vnorm','Eta1','Eta2','A','Kappa','Ter','St','Psi'});
end
