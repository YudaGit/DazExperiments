function [ll, ll2, qaic, qbic, Pred] = test_yljpcau(Pvar, Pfix, Sel, Data, trace)
%TEST_YLJPCAU JP-CDM likelihood with psi fixed at -1.
%   Baseline test wrapper, no category-bias layer.
%
%   P = [vnormS2:vnormS6, kappa1:kappa9, eta, a, Ter, st]
%        1:3              4:12           13   14 15   16

    if nargin < 5
        trace = 0;
    end

    meta = local_meta();
    np = 16;
    [ll, ll2, qaic, qbic, Pred] = local_eval_model(Pvar, Pfix, Sel, Data, trace, np, meta);
end

function [ll, ll2, qaic, qbic, Pred] = local_eval_model(Pvar, Pfix, Sel, Data, trace, np, meta)
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

    [lb, ub, plb, pub] = local_bounds();
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

    vnorm = P(1:3);
    kappa = P(4:12);
    eta = P(13);
    a = P(14);
    Ter = P(15);
    st = P(16);
    psi = -1.0;
    sigma = 1.0;

    llRaw = 0;
    Gstuff = cell(3, nCond);
    Predstuff = cell(3, nCond);
    CircSD = zeros(1, nCond);
    N = 0;

    for c = 1:nCond
        setIdx = meta.setIndexByCond(c);
        Pc = [vnorm(setIdx), kappa(c), eta, psi, sigma, a];
        [tc, gtmc, ftmc, thetac, pthetac, mthetac, mdthetac, ethetac, llc] = ...
            local_condition_likelihood(Pc, Data{c}, Ter, st, meta);

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

    [t, gt, theta, ptheta, mtheta] = vjp300rot( ...
        [Pc(1), Pc(2), Pc(3), 0, Pc(4), Pc(5), Pc(6)], ...
        meta.tmax, meta.noise);

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
    meta.setIndexByCond = [1, 2, 2, 2, 3, 3, 3, 3, 3];
    meta.tmax = 3.0;
    meta.rtMin = 0.3;
    meta.noise = 1e-12;
    meta.nw = 50;
    meta.sz = 300;
end

function [lb, ub, plb, pub] = local_bounds()
    lb = [2 * ones(1, 3), 0.001 * ones(1, 9), 0.02, 2.0, 0, 0];
    ub = [12 * ones(1, 3), 80.0 * ones(1, 9), 8.0, 12.0, 1, 0.7];
    plb = [2.5 * ones(1, 3), 0.01 * ones(1, 9), 0.05, 2.5, 0, 0.01];
    pub = [11.5 * ones(1, 3), 70.0 * ones(1, 9), 7.0, 11.5, 0.8, 0.6];
end
