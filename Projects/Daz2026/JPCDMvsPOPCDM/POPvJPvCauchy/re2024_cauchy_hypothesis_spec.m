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
            ["H0", "H1_ETA", "H1_VNORM", "H1_TER", "H_SATDECISION", ...
             "H2_FACTORIAL", "H2_TSENSITIVE", ...
             "H3_1T_VSET", "H3_1T_VCOLOR", "H3_1V_TCOLOR", "H3_1V_TSET"])
        error('re2024_cauchy_hypothesis_spec:UnknownHypothesis', ...
            'Unknown Cauchy hypothesis: %s.', hypothesis);
    end

    setLevels = ["S2", "S4", "S6"];
    colourLevels = ["C2", "C4", "C6"];
    setIndexByCond = [1, 2, 2, 2, 3, 3, 3, 3, 3];
    colourIndexByCond = [1, 1, 1, 2, 1, 1, 2, 2, 3];
    baseRNrIndexByCond = [1, 3, 2, 1, 3, 2, 3, 2, 1];
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
        case "H_SATDECISION"
            vnormNames = "vnorm_" + condLevels;
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta_" + condLevels;
            terNames = "Ter_" + condLevels;
            vnormByCond = 1:nCond;
            kappaByCond = 1:nCond;
            etaByCond = 1:nCond;
            terByCond = 1:nCond;
        case "H2_FACTORIAL"
            vnormNames = "vnorm_" + setLevels;
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta_" + colourLevels;
            terNames = ["Ter_Base", "Ter_R", "Ter_NR"];
            vnormByCond = setIndexByCond;
            kappaByCond = 1:nCond;
            etaByCond = colourIndexByCond;
            terByCond = baseRNrIndexByCond;
        case "H2_TSENSITIVE"
            vnormNames = "vnorm_" + setLevels;
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = ["Ter_C2", "Ter_C4", "Ter_C6", ...
                "deltaTer_R", "deltaTer_NR"];
            vnormByCond = setIndexByCond;
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = colourIndexByCond;
        case "H3_1T_VSET"
            vnormNames = ["vnorm_" + setLevels, "deltaVnorm_R", "deltaVnorm_NR"];
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = "Ter";
            vnormByCond = setIndexByCond;
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = ones(1, nCond);
        case "H3_1T_VCOLOR"
            vnormNames = ["vnorm_" + colourLevels, "deltaVnorm_R", "deltaVnorm_NR"];
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = "Ter";
            vnormByCond = colourIndexByCond;
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = ones(1, nCond);
        case "H3_1V_TCOLOR"
            vnormNames = "vnorm";
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = ["Ter_C2", "Ter_C4", "Ter_C6", ...
                "deltaTer_R", "deltaTer_NR"];
            vnormByCond = ones(1, nCond);
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = colourIndexByCond;
        case "H3_1V_TSET"
            vnormNames = "vnorm";
            kappaNames = "kappa_" + condLevels;
            etaNames = "eta";
            terNames = ["Ter_S2", "Ter_S4", "Ter_S6", ...
                "deltaTer_R", "deltaTer_NR"];
            vnormByCond = ones(1, nCond);
            kappaByCond = 1:nCond;
            etaByCond = ones(1, nCond);
            terByCond = setIndexByCond;
    end

    nVnorm = numel(vnormNames);
    nKappa = numel(kappaNames);
    nEta = numel(etaNames);
    nTer = numel(terNames);
    spec.hypothesis = hypothesis;
    spec.condLevels = condLevels;
    spec.vnormByCond = vnormByCond;
    spec.vnormOffsetByCond = zeros(1, nCond);
    if ismember(hypothesis, ["H3_1T_VSET", "H3_1T_VCOLOR"])
        spec.vnormOffsetByCond = [0, 5, 4, 0, 5, 4, 5, 4, 0];
    end
    spec.kappaByCond = kappaByCond;
    spec.etaByCond = etaByCond;
    spec.terByCond = terByCond;
    spec.terOffsetByCond = zeros(1, nCond);
    if hypothesis == "H2_TSENSITIVE" || ...
            ismember(hypothesis, ["H3_1V_TCOLOR", "H3_1V_TSET"])
        % Grouped baseline Ter plus an additive cue-state increment.
        spec.terOffsetByCond = [0, 5, 4, 0, 5, 4, 5, 4, 0];
    end
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
    if hypothesis == "H_SATDECISION"
        spec.layoutVersion = "20260922_satDecision_vnorm_kappa_eta_a_ter_st";
    elseif hypothesis == "H3_1T_VSET"
        spec.layoutVersion = "20260929_h3_1t_vset_vnorm_kappa_eta_a_ter_st";
    elseif hypothesis == "H3_1T_VCOLOR"
        spec.layoutVersion = "20260930_h3_1t_vcolor_vnorm_kappa_eta_a_ter_st";
    elseif hypothesis == "H3_1V_TCOLOR"
        spec.layoutVersion = "20260929_h3_1v_tcolor_vnorm_kappa_eta_a_ter_st";
    elseif hypothesis == "H3_1V_TSET"
        spec.layoutVersion = "20260930_h3_1v_tset_vnorm_kappa_eta_a_ter_st";
    elseif hypothesis == "H2_FACTORIAL" || hypothesis == "H2_TSENSITIVE"
        spec.layoutVersion = "20260922_h2factor_vnorm_kappa_eta_a_ter_st";
    else
        spec.layoutVersion = "20260915_vnorm_kappa_eta_a_ter_st";
    end

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
    spec.A = zeros(0, numel(spec.P0));
    spec.b = zeros(0, 1);
    if ismember(hypothesis, ["H3_1T_VSET", "H3_1T_VCOLOR"])
        % Signed cue offsets, constrained so every derived vnorm is in [2, 12].
        offsetIndex = spec.index.vnorm(4:5);
        spec.P0(offsetIndex) = 0;
        spec.lb(offsetIndex) = -10;
        spec.ub(offsetIndex) = 10;
        spec.plb(offsetIndex) = -10;
        spec.pub(offsetIndex) = 10;
        for baseIndex = unique(vnormByCond(spec.vnormOffsetByCond > 0))
            for j = 1:numel(offsetIndex)
                upperConstraint = zeros(1, numel(spec.P0));
                upperConstraint(spec.index.vnorm(baseIndex)) = 1;
                upperConstraint(offsetIndex(j)) = 1;
                spec.A = [spec.A; upperConstraint; -upperConstraint]; %#ok<AGROW>
                spec.b = [spec.b; 12; -2]; %#ok<AGROW>
            end
        end
    end
    if hypothesis == "H2_TSENSITIVE" || ...
            ismember(hypothesis, ["H3_1V_TCOLOR", "H3_1V_TSET"])
        % Allow signed cue offsets, while keeping every derived Ter in [0, 1].
        spec.P0(spec.index.Ter) = [0.25, 0.25, 0.25, 0, 0];
        spec.lb(spec.index.Ter) = [0, 0, 0, -1, -1];
        spec.ub(spec.index.Ter) = [1, 1, 1, 1, 1];
        spec.plb(spec.index.Ter) = [0, 0, 0, -0.8, -0.8];
        spec.pub(spec.index.Ter) = [0.8, 0.8, 0.8, 0.8, 0.8];
        terIndex = spec.index.Ter;
        for baseIndex = unique(terByCond(spec.terOffsetByCond > 0))
            for offsetIndex = 4:5
                upperConstraint = zeros(1, numel(spec.P0));
                upperConstraint(terIndex(baseIndex)) = 1;
                upperConstraint(terIndex(offsetIndex)) = 1;
                lowerConstraint = -upperConstraint;
                spec.A = [spec.A; upperConstraint; lowerConstraint]; %#ok<AGROW>
                spec.b = [spec.b; 1; 0]; %#ok<AGROW>
            end
        end
    end
end
