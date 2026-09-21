function spec = re2024_cauchy_hypothesis_spec(hypothesis, condLevels)
%RE2024_CAUCHY_HYPOTHESIS_SPEC Define transparent Cauchy test routes.
%   Every route uses the same Cauchy-CDM likelihood. This helper only
%   specifies which parameter varies across the nine experimental cells.

    if nargin < 2 || isempty(condLevels)
        condLevels = ["S2C2NR", ...
            "S4C2NR", "S4C2R", "S4C4NR", ...
            "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6NR"];
    end
    condLevels = string(condLevels);
    nCond = numel(condLevels);
    hypothesis = upper(string(hypothesis));

    if ~isscalar(hypothesis) || ~ismember(hypothesis, ...
            ["H0", "H1_ETA", "H1_VNORM", "H1_TER", ...
             "H1_VNORM_SN", "LEGACY_ETA_CELL_VNORM_SN"])
        error('re2024_cauchy_hypothesis_spec:UnknownHypothesis', ...
            'Unknown Cauchy hypothesis: %s.', hypothesis);
    end

    setLabels = ["S2", "S4", "S6"];
    setIndexByCond = [1, 2, 2, 2, 3, 3, 3, 3, 3];
    switch hypothesis
        case "H0"
            vnormNames = "vnorm";
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = "Ter";
            vnormByCond = ones(1, nCond);
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = ones(1, nCond);
        case "H1_VNORM_SN"
            vnormNames = "vnorm" + setLabels;
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = "Ter";
            vnormByCond = setIndexByCond;
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = ones(1, nCond);
        case "LEGACY_ETA_CELL_VNORM_SN"
            vnormNames = "vnorm" + setLabels;
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta_" + condLevels;
            terNames = "Ter";
            vnormByCond = setIndexByCond;
            kappaByCond = 1:nCond;
            etaByCond = 1:nCond;
            terByCond = ones(1, nCond);
        case "H1_ETA"
            vnormNames = "vnorm";
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta_" + condLevels;
            terNames = "Ter";
            vnormByCond = ones(1, nCond);
            kappaByCond = 1:nCond;
            etaByCond = 1:nCond;
            terByCond = ones(1, nCond);
        case "H1_VNORM"
            vnormNames = "vnorm_" + condLevels;
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = "Ter";
            vnormByCond = 1:nCond;
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = ones(1, nCond);
        case "H1_TER"
            vnormNames = "vnorm";
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = "Ter_" + condLevels;
            vnormByCond = ones(1, nCond);
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = 1:nCond;
    end

    nVnorm = numel(vnormNames);
    nKappa = numel(kappaNames);
    nEta = numel(etaNames);
    nTer = numel(terNames);
    spec.hypothesis = hypothesis;
    spec.condLevels = condLevels;
    spec.vnormByCond = vnormByCond;
    spec.kappaByCond = kappaByCond;
    spec.etaByCond = etaByCond;
    spec.terByCond = terByCond;
    spec.index.vnorm = 1:nVnorm;
    spec.index.kappa = nVnorm + (1:nKappa);
    spec.index.eta = nVnorm + nKappa + (1:nEta);
    spec.index.a = nVnorm + nKappa + nEta + 1;
    spec.index.Ter = nVnorm + nKappa + nEta + 1 + (1:nTer);
    spec.index.st = spec.index.Ter(end) + 1;
    % Canonical vector order for every Re2024 Cauchy route.  Keep this
    % ordering stable: saved fits and warm starts are matched by name, while
    % wrappers interpret values through the index fields above.
    spec.paramNames = [vnormNames, kappaNames, etaNames, "a", terNames, "st"];
    spec.layoutVersion = "20260915_vnorm_kappa_eta_a_ter_st";

    % Values and bounds remain on the team-Cauchy parameter scale.
    spec.P0 = [6 * ones(1, nVnorm), 0.10 * ones(1, nKappa), ...
        0.50 * ones(1, nEta), 6, 0.25 * ones(1, nTer), 0.20];
    spec.lb = [2 * ones(1, nVnorm), 0.001 * ones(1, nKappa), ...
        0.02 * ones(1, nEta), 2, zeros(1, nTer), 0];
    spec.ub = [12 * ones(1, nVnorm), 2.0 * ones(1, nKappa), ...
        8.0 * ones(1, nEta), 12, ones(1, nTer), 0.7];
    spec.plb = [2.5 * ones(1, nVnorm), 0.01 * ones(1, nKappa), ...
        0.05 * ones(1, nEta), 2.5, zeros(1, nTer), 0.01];
    spec.pub = [11.5 * ones(1, nVnorm), 1.5 * ones(1, nKappa), ...
        7.0 * ones(1, nEta), 11.5, 0.8 * ones(1, nTer), 0.6];
end
