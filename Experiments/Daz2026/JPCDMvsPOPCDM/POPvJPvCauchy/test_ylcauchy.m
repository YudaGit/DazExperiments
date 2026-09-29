function [ll, ll2, qaic, qbic, Pred] = test_ylcauchy(Pvar, Pfix, Sel, Data, trace, hypothesisOrSpec)
%TEST_YLCAUCHY Cauchy-CDM likelihood for one Re2024 participant.
%   Parameter layouts are defined by re2024_cauchy_hypothesis_spec. The
%   runner may also pass an already-built spec so its bounds and the wrapper
%   interpretation are guaranteed to use the same parameter ordering.

    if nargin < 5 || isempty(trace)
        trace = 0;
    end
    meta = local_meta();
    if nargin < 6 || isempty(hypothesisOrSpec)
        hypothesisOrSpec = "H0";
    end
    if isstruct(hypothesisOrSpec)
        spec = hypothesisOrSpec;
        if ~isfield(spec, 'condLevels') || ...
                ~isequal(string(spec.condLevels), meta.condLevels)
            error('test_ylcauchy:InvalidSpecification', ...
                'The supplied specification does not match Re2024 conditions.');
        end
    else
        spec = re2024_cauchy_hypothesis_spec( ...
            hypothesisOrSpec, meta.condLevels);
    end
    np = numel(spec.P0);
    [ll, ll2, qaic, qbic, Pred] = local_eval_model( ...
        Pvar, Pfix, Sel, Data, trace, np, meta, spec);
end

function [ll, ll2, qaic, qbic, Pred] = local_eval_model(Pvar, Pfix, Sel, Data, trace, np, meta, spec)
    tau2 = 1.0;
    nCond = numel(meta.condLevels);
    Pred = [];

    if length(Pvar) + length(Pfix) ~= np
        error('%s:IncorrectParameterCount', mfilename, ...
            'Pvar plus Pfix must contain %d parameters.', np);
    end
    if length(Sel) ~= np
        error('%s:IncorrectSelectorLength', mfilename, ...
            'Sel must contain %d entries.', np);
    end
    if any(size(Data) ~= [1, nCond])
        error('%s:IncorrectDataShape', mfilename, ...
            'Data must be a 1 x %d cell array for one participant.', nCond);
    end

    P = zeros(1, np);
    P(Sel == 1) = Pvar;
    P(Sel == 0) = Pfix;

    lb = spec.lb;
    ub = spec.ub;
    plb = spec.plb;
    pub = spec.pub;
    lbFree = lb(Sel == 1);
    ubFree = ub(Sel == 1);
    if any(Pvar < lbFree) || any(Pvar > ubFree)
        ll = 1e7 + 1e3 * (sum(max(Pvar - ubFree, 0).^2) + ...
            sum(max(lbFree - Pvar, 0).^2));
        ll2 = 2 * abs(ll);
        qaic = 0;
        qbic = 0;
        return
    end

    penalty = 1e3 * (sum(max(P - pub, 0).^2) + sum(max(plb - P, 0).^2));
    if trace
        disp(max(P - pub, 0));
        disp(max(plb - P, 0));
        disp(penalty);
    end

    vnorm = P(spec.index.vnorm);
    kappa = P(spec.index.kappa);
    eta = P(spec.index.eta);
    a = P(spec.index.a);
    Ter = P(spec.index.Ter);
    st = P(spec.index.st);
    sigma = 1.0;

    llRaw = 0;
    Gstuff = cell(3, nCond);
    Predstuff = cell(3, nCond);
    CircSD = zeros(1, nCond);
    N = 0;

    for c = 1:nCond
        Pc = [vnorm(spec.vnormByCond(c)), kappa(spec.kappaByCond(c)), ...
            eta(spec.etaByCond(c)), sigma, a];
        TerC = Ter(spec.terByCond(c));
        if isfield(spec, 'terOffsetByCond') && spec.terOffsetByCond(c) > 0
            TerC = TerC + Ter(spec.terOffsetByCond(c));
        end
        [tc, gtmc, ftmc, thetac, pthetac, mthetac, mdthetac, ethetac, llc] = ...
            local_condition_likelihood(Pc, Data{c}, TerC, st, meta);

        N = N + size(Data{c}, 1);
        llRaw = llRaw + sum(llc);
        CircSD(c) = local_circular_standard_deviation(thetac, pthetac);
        Gstuff{1, c} = tc;
        Gstuff{2, c} = thetac;
        Gstuff{3, c} = gtmc;
        Predstuff{1, c} = [tc; ftmc];
        Predstuff{2, c} = [thetac; pthetac];
        Predstuff{3, c} = [thetac; ethetac; mthetac; mdthetac];
    end

    Pred = cell(3, 1);
    Pred{1} = Predstuff;
    Pred{2} = Gstuff;
    Pred{3} = CircSD;

    ll2 = 2 * abs(llRaw);
    qaic = ll2 / tau2 + 2 * sum(Sel);
    qbic = ll2 / tau2 + sum(Sel) * log(N);
    ll = abs(llRaw) + penalty;
end

function [t, gtm, ftm, theta, ptheta, mtheta, mdtheta, etheta, ll0] = ...
        local_condition_likelihood(Pc, Dataj, Ter, st, meta)
    h = meta.tmax / meta.sz;
    w = 2 * pi / meta.nw;
    epsx = 1e-9;
    likeFloor = 1e-12;

    [t, gt, theta, ptheta, mtheta] = vcau300rot( ...
        [Pc(1), Pc(2), Pc(3), 0, Pc(4), Pc(5)], meta.tmax, meta.noise);

    gt = max(gt, epsx);
    t = t + Ter + st / 2;
    if st > 2 * h
        h = t(2) - t(1);
        m = round(st / h);
        n = length(t);
        fe = ones(1, m) / m;
        for i = 1:(meta.nw + 1)
            gti = conv(gt(i, :), fe);
            gt(i, :) = gti(1:n);
        end
    end
    mtheta = mtheta + Ter + st / 2;

    keep = t >= meta.rtMin & t <= meta.tmax;
    totalMass = sum(gt(1:meta.nw, keep), 'all') * w * h;
    if totalMass > 0
        gt = gt / totalMass;
    end

    l0 = interp2(t, theta, gt, Dataj(:, 3), Dataj(:, 2), 'linear', likeFloor);
    bad = isnan(l0) | l0 <= likeFloor;
    l0(bad) = likeFloor;
    ll0 = -log(l0);

    gtm = gt(1:meta.nw, :);
    ftm = sum(gtm, 1) * w;
    pthetaUnique = ptheta(1:meta.nw);
    pthetaUnique = pthetaUnique(:)';
    mthetaUnique = mtheta(1:meta.nw);
    mthetaUnique = mthetaUnique(:)';
    mdthetaUnique = local_rt_median_by_angle(gtm, t, w, h);
    ethetaScalar = sum(pthetaUnique(:)' .* theta(1:meta.nw)) * w;

    ptheta = [pthetaUnique, pthetaUnique(1)];
    mtheta = [mthetaUnique, mthetaUnique(1)];
    mdtheta = [mdthetaUnique, mdthetaUnique(1)];
    etheta = ethetaScalar * ones(1, numel(theta));
end

function mdtheta = local_rt_median_by_angle(gtm, t, w, h)
    nw = size(gtm, 1);
    mdtheta = zeros(1, nw);
    ft = cumsum(gtm, 2) * w * h;
    for i = 1:nw
        ix = find(ft(i, :) >= 0.5, 1, 'first');
        if isempty(ix)
            mdtheta(i) = t(end);
        else
            mdtheta(i) = t(ix);
        end
    end
end

function cse = local_circular_standard_deviation(theta, ptheta)
    theta = theta(1:numel(ptheta));
    w = theta(2) - theta(1);
    Ctheta = ptheta(:)' .* cos(theta);
    Stheta = ptheta(:)' .* sin(theta);
    Rbar = sqrt((sum(Ctheta) * w)^2 + (sum(Stheta) * w)^2);
    cse = sqrt(-2 * log(Rbar));
end

function meta = local_meta()
    meta.condLevels = ["S2C2NR", ...
        "S4C2NR", "S4C2R", "S4C4NR", ...
        "S6C2NR", "S6C2R", "S6C4NR", "S6C4R", "S6C6NR"];
    meta.tmax = 3.0;
    meta.rtMin = 0.3;
    meta.noise = 1e-12;
    meta.nw = 50;
    meta.sz = 300;
end
