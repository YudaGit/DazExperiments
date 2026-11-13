function catalog = pop_theory_models()
%POP_THEORY_MODELS Sel / Pvar / Pfix layouts for theory hypotheses.
%
% Full vector P uses the Example Fitting Package contract:
%   P(Sel==1) = Pvar   (free, passed to fmincon)
%   P(Sel==0) = Pfix  (fixed)
%
% Current models (shared RT skeleton unless noted):
%   H0a : 1 kappa, 9 condition alphas
%   H0b : 1 alpha, 9 condition kappas
%   H1  : 1 kappa, 3-beta power-law alpha (restriction of H0a)
% Shared: 3 set-size vnorms (S2/S4/S6); singleton eta1/a/ter/st; eta2 = exp(-6)
%
% Power-law amplitude (H1; manuscript-consistent):
%   Free A2 at Nc=2. Each route: A1 = A2*2^(-beta_route).
%   Baseline: A1_U*Nc^beta_U
%   NR:       A1_NR*Nc^beta_NR
%   R:        A1_R*Nc^beta_R * m^(-beta_R), m=S-C+1

    condLevels = ["S2C2NR", "S4C2NR", "S4C2R", ...
                  "S4C4NR", "S6C2NR", "S6C2R", ...
                  "S6C4NR", "S6C4R", "S6C6NR"];
    nCond = numel(condLevels);
    eta2Fixed = exp(-6);

    paramNames = [ ...
        "vnormS2", "vnormS4", "vnormS6", ...
        "eta1", "a", ...
        "terC2", "terC4", "terC6", ...
        "kappa_shared", ...
        "kappa_" + condLevels, ...
        "A2", "beta_U", "beta_NR", "beta_R", ...
        "alpha_shared", ...
        "alpha_" + condLevels, ...
        "eta2_shared", ...
        "eta2_" + condLevels, ...
        "st"];
    np = numel(paramNames);

    P0 = zeros(1, np);
    lb = zeros(1, np);
    ub = zeros(1, np);

    % vnorm groups by set size (S2 / S4 / S6)
    % Box chosen so recent MLEs sit interior (v ~4.5–9.8, a ~3.5–9.5).
    P0(1:3) = 6.0;   lb(1:3) = 2.0; ub(1:3) = 12.0;
    % eta1, a (same numeric box as vnorm)
    P0(4) = 0.50;    lb(4) = 0.02;  ub(4) = 8.0;
    P0(5) = 6.00;    lb(5) = 2.0;  ub(5) = 12.0;
    % ter by color count (current models free only terC2, shared across conditions)
    P0(6:8) = 0.25;  lb(6:8) = 0.00; ub(6:8) = 1.0;
    % shared kappa + condition kappas
    P0(9) = 15.0;    lb(9) = 0.01;  ub(9) = 30.0;
    ixKappaCond = 10:(9 + nCond);
    P0(ixKappaCond) = 15.0;
    lb(ixKappaCond) = 0.01;
    ub(ixKappaCond) = 30.0;

    % Manuscript 3-beta power law: A2 and betas in [-1, 0]
    ixA2 = 10 + nCond;
    ixBetaU = ixA2 + 1;
    ixBetaNR = ixA2 + 2;
    ixBetaR = ixA2 + 3;
    P0(ixA2) = 20.0;     lb(ixA2) = 0.01;  ub(ixA2) = 300.0;
    P0(ixBetaU) = -0.50; lb(ixBetaU) = -1.0; ub(ixBetaU) = 0.0;
    P0(ixBetaNR) = -0.50; lb(ixBetaNR) = -1.0; ub(ixBetaNR) = 0.0;
    P0(ixBetaR) = -0.50;  lb(ixBetaR) = -1.0;  ub(ixBetaR) = 0.0;

    % shared alpha (H0b) + free alphas (H0a)
    ixAlphaShared = ixBetaR + 1;
    P0(ixAlphaShared) = 20.0;
    lb(ixAlphaShared) = 0.01;
    ub(ixAlphaShared) = 300.0;

    ixAlphaCond = (ixAlphaShared + 1):(ixAlphaShared + nCond);
    P0(ixAlphaCond) = 20.0;
    lb(ixAlphaCond) = 0.01;
    ub(ixAlphaCond) = 300.0;

    % eta2 shared + condition; current models keep eta2_shared in Pfix
    ixEta2Shared = ixAlphaCond(end) + 1;
    ixEta2Cond = (ixEta2Shared + 1):(ixEta2Shared + nCond);
    P0(ixEta2Shared) = eta2Fixed;
    lb(ixEta2Shared) = eta2Fixed;
    ub(ixEta2Shared) = 5.0;
    P0(ixEta2Cond) = eta2Fixed;
    lb(ixEta2Cond) = eta2Fixed;
    ub(ixEta2Cond) = 5.0;

    % st free in all hypotheses
    ixSt = ixEta2Cond(end) + 1;
    P0(ixSt) = 0.20; lb(ixSt) = 0.00; ub(ixSt) = 0.70;

    assert(ixSt == np, 'Parameter layout length mismatch.');

    index.vnorm = 1:3;
    index.eta1 = 4;
    index.a = 5;
    index.ter = 6:8;
    index.kappaShared = 9;
    index.kappaCond = ixKappaCond;
    index.A2 = ixA2;
    index.betaU = ixBetaU;
    index.betaNR = ixBetaNR;
    index.betaR = ixBetaR;
    index.alphaShared = ixAlphaShared;
    index.alphaCond = ixAlphaCond;
    index.eta2Shared = ixEta2Shared;
    index.eta2Cond = ixEta2Cond;
    index.st = ixSt;

    design = local_condition_design(condLevels);

    catalog.condLevels = condLevels;
    catalog.paramNames = paramNames;
    catalog.P0 = P0;
    catalog.lb = lb;
    catalog.ub = ub;
    catalog.index = index;
    catalog.design = design;
    catalog.colorCountRef = 2;
    catalog.eta2Fixed = eta2Fixed;
    catalog.np = np;

    catalog.H0a = make_hypothesis( ...
        "H0a", ...
        "baseline: 1 kappa, 9 alphas; vnorm by set size; singleton ter; eta2=exp(-6)", ...
        index, "shared", "free", "fixed", "setsize", "shared", np);

    catalog.H0b = make_hypothesis( ...
        "H0b", ...
        "baseline: 1 alpha, 9 kappas; vnorm by set size; singleton ter; eta2=exp(-6)", ...
        index, "free", "shared", "fixed", "setsize", "shared", np);

    catalog.H1 = make_hypothesis( ...
        "H1", ...
        "H0a with 3-beta power-law alpha instead of 9 free alphas", ...
        index, "shared", "powerlaw", "fixed", "setsize", "shared", np);
end

function hyp = make_hypothesis( ...
        name, description, index, kappaMode, alphaMode, eta2Mode, ...
        vnormMode, terMode, np)
    Sel = false(1, np);
    Sel([index.eta1, index.a, index.st]) = true;

    switch vnormMode
        case "shared"
            Sel(index.vnorm(1)) = true;
        case {"grouped", "setsize"}
            Sel(index.vnorm) = true;
        otherwise
            error('Unknown vnormMode: %s', vnormMode);
    end

    switch terMode
        case "shared"
            Sel(index.ter(1)) = true;
        case "color"
            Sel(index.ter) = true;
        otherwise
            error('Unknown terMode: %s', terMode);
    end

    switch kappaMode
        case "shared"
            Sel(index.kappaShared) = true;
        case "free"
            Sel(index.kappaCond) = true;
        otherwise
            error('Unknown kappaMode: %s', kappaMode);
    end

    switch alphaMode
        case "powerlaw"
            Sel([index.A2, index.betaU, index.betaNR, index.betaR]) = true;
        case "free"
            Sel(index.alphaCond) = true;
        case "shared"
            Sel(index.alphaShared) = true;
        otherwise
            error('Unknown alphaMode: %s', alphaMode);
    end

    switch eta2Mode
        case "fixed"
            % eta2_shared stays in Pfix
        case "free"
            Sel(index.eta2Cond) = true;
        otherwise
            error('Unknown eta2Mode: %s', eta2Mode);
    end

    hyp.name = name;
    hyp.description = description;
    hyp.Sel = Sel;
    hyp.nFree = sum(Sel);
    hyp.kappaMode = kappaMode;
    hyp.alphaMode = alphaMode;
    hyp.eta2Mode = eta2Mode;
    hyp.vnormMode = vnormMode;
    hyp.terMode = terMode;
    hyp.freeNames = strings(0, 1);
end

function design = local_condition_design(condLevels)
    nCond = numel(condLevels);
    nItems = zeros(nCond, 1);
    nColors = zeros(nCond, 1);
    isRedundant = false(nCond, 1);
    trialKind = strings(nCond, 1);

    for c = 1:nCond
        tok = char(condLevels(c));
        nItems(c) = str2double(tok(2));
        nColors(c) = str2double(tok(4));
        isRedundant(c) = ~endsWith(condLevels(c), "NR");
        if nItems(c) == nColors(c)
            trialKind(c) = "baseline";
        elseif isRedundant(c)
            trialKind(c) = "R";
        else
            trialKind(c) = "NR";
        end
    end
    nRedundant = nItems - nColors + 1;

    design = table(condLevels(:), nItems, nColors, isRedundant, nRedundant, ...
        trialKind, ...
        'VariableNames', {'Cond', 'nItems', 'nColors', 'isRedundant', ...
                          'nRedundant', 'trialKind'});
end
