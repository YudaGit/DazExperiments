function condFit = pop_theory_expand_P(P, hyp, catalog)
%POP_THEORY_EXPAND_P Map full theory vector P to condition-level POPCDM params.
%
% Manuscript-consistent 3-beta power law (beta in [-1, 0]; sample-size = -0.5):
%   Free: A2 = POP alpha at Nc = 2 (shared across routes).
%   Each route scales back to its own theoretical A1 with its own beta:
%     A1_U  = A2 * 2^(-beta_U)
%     A1_NR = A2 * 2^(-beta_NR)
%     A1_R  = A2 * 2^(-beta_R)
%   Then:
%     Baseline: Alpha = A1_U  * Nc^beta_U
%     NR:       Alpha = A1_NR * Nc^beta_NR
%     R (PS):   Alpha = A1_R  * Nc^beta_R * m^(-beta_R),  m = S-C+1
%
% Equivalent compact form: Alpha = A2 * (Nc/2)^beta * [m^(-beta) if R].
% At Nc=2, baseline and NR both recover Alpha = A2.

    index = catalog.index;
    condLevels = catalog.condLevels;
    design = catalog.design;
    nCond = numel(condLevels);

    vnormS2 = P(index.vnorm(1));
    vnormS4 = P(index.vnorm(2));
    vnormS6 = P(index.vnorm(3));
    eta1 = P(index.eta1);
    a = P(index.a);
    terGroups = P(index.ter);
    st = P(index.st);

    usePowerLaw = isfield(hyp, 'alphaMode') && hyp.alphaMode == "powerlaw";
    if usePowerLaw
        A2 = P(index.A2);
        betaU = P(index.betaU);
        betaNR = P(index.betaNR);
        betaR = P(index.betaR);
        A1U = A2 * (2 ^ (-betaU));
        A1NR = A2 * (2 ^ (-betaNR));
        A1R = A2 * (2 ^ (-betaR));
    else
        A2 = NaN;
        betaU = NaN;
        betaNR = NaN;
        betaR = NaN;
        A1U = NaN;
        A1NR = NaN;
        A1R = NaN;
    end

    vnorm = nan(nCond, 1);
    ter = nan(nCond, 1);
    alpha = nan(nCond, 1);
    kappa = nan(nCond, 1);
    eta2 = nan(nCond, 1);
    betaUsed = nan(nCond, 1);
    A1Used = nan(nCond, 1);
    alphaM = nan(nCond, 1);
    kind = strings(nCond, 1);

    for c = 1:nCond
        cond = condLevels(c);
        row = design(c, :);
        kind(c) = string(row.trialKind);
        if ~isfield(hyp, 'vnormMode') || hyp.vnormMode == "setsize" ...
                || hyp.vnormMode == "grouped"
            vnorm(c) = map_setsize_vnorm(row.nItems, vnormS2, vnormS4, vnormS6);
        else
            vnorm(c) = vnormS2;
        end
        if ~isfield(hyp, 'terMode') || hyp.terMode == "color"
            ter(c) = map_color_ter(cond, terGroups);
        else
            ter(c) = terGroups(1);
        end

        switch hyp.kappaMode
            case "shared"
                kappa(c) = P(index.kappaShared);
            case "free"
                kappa(c) = P(index.kappaCond(c));
            otherwise
                error('Unknown kappaMode.');
        end

        switch hyp.alphaMode
            case "powerlaw"
                [alpha(c), betaUsed(c), A1Used(c), alphaM(c)] = ...
                    manuscript_alpha( ...
                    row.nColors, row.nRedundant, kind(c), ...
                    A1U, A1NR, A1R, betaU, betaNR, betaR);
            case "free"
                alphaM(c) = NaN;
                betaUsed(c) = NaN;
                A1Used(c) = NaN;
                alpha(c) = P(index.alphaCond(c));
            case "shared"
                alphaM(c) = NaN;
                betaUsed(c) = NaN;
                A1Used(c) = NaN;
                alpha(c) = P(index.alphaShared);
            otherwise
                error('Unknown alphaMode.');
        end

        switch hyp.eta2Mode
            case "fixed"
                eta2(c) = P(index.eta2Shared);
            case "free"
                eta2(c) = P(index.eta2Cond(c));
            otherwise
                error('Unknown eta2Mode.');
        end
    end

    condFit = table(condLevels(:), kind, vnorm, ...
        repmat(eta1, nCond, 1), eta2, repmat(a, nCond, 1), ...
        alpha, kappa, ter, repmat(st, nCond, 1), ...
        repmat(A2, nCond, 1), A1Used, ...
        repmat(A1U, nCond, 1), repmat(A1NR, nCond, 1), repmat(A1R, nCond, 1), ...
        betaUsed, alphaM, ...
        repmat(betaU, nCond, 1), repmat(betaNR, nCond, 1), repmat(betaR, nCond, 1), ...
        'VariableNames', {'Cond', 'TrialKind', 'Vnorm', 'Eta1', 'Eta2', 'A', ...
                          'Alpha', 'Kappa', 'Ter', 'St', ...
                          'A2', 'A1', 'A1U', 'A1NR', 'A1R', ...
                          'BetaUsed', 'AlphaM', ...
                          'BetaU', 'BetaNR', 'BetaR'});
end

function [alpha, betaUsed, A1Used, mFactor] = manuscript_alpha( ...
        nColors, nRedundant, trialKind, A1U, A1NR, A1R, betaU, betaNR, betaR)
% Each route uses its own A1 = A2*2^(-beta_route) and its own beta.
%   Baseline: Alpha = A1_U  * Nc^beta_U
%   NR:       Alpha = A1_NR * Nc^beta_NR
%   R:        Alpha = A1_R  * Nc^beta_R * m^(-beta_R)
% Equivalent: Alpha = A2 * (Nc/2)^beta * [m^(-beta) if R].

    nc = double(nColors);
    m = double(nRedundant);

    switch trialKind
        case "baseline"
            betaUsed = betaU;
            A1Used = A1U;
            mFactor = nc ^ betaUsed;
        case "NR"
            betaUsed = betaNR;
            A1Used = A1NR;
            mFactor = nc ^ betaUsed;
        case "R"
            betaUsed = betaR;
            A1Used = A1R;
            if ~(isfinite(m) && m >= 1)
                error('Invalid redundant count m=%g.', m);
            end
            mFactor = (nc ^ betaUsed) * (m ^ (-betaUsed));
        otherwise
            error('Unknown trialKind: %s', trialKind);
    end

    if ~(isfinite(mFactor) && mFactor > 0)
        error('Invalid power-law factor (beta=%g, Nc=%g, m=%g).', ...
            betaUsed, nc, m);
    end
    alpha = A1Used * mFactor;
    if ~(isfinite(alpha) && alpha > 0)
        error('Invalid power-law alpha.');
    end
end

function ter = map_color_ter(cond, terGroups)
    if contains(cond, "C2")
        ter = terGroups(1);
    elseif contains(cond, "C4")
        ter = terGroups(2);
    elseif contains(cond, "C6")
        ter = terGroups(3);
    else
        error('Unexpected condition in ter mapping: %s', cond);
    end
end

function vnorm = map_setsize_vnorm(nItems, vnormS2, vnormS4, vnormS6)
    switch double(nItems)
        case 2
            vnorm = vnormS2;
        case 4
            vnorm = vnormS4;
        case 6
            vnorm = vnormS6;
        otherwise
            error('Unexpected set size in vnorm mapping: %g', nItems);
    end
end
