function nll = jpcdm_nll_2cond(Q, d, tmax)
%=======================
% jpcdm_nll_2cond
%=======================
% Q = [vnorm, eta, a, ter, st, kappa1, psi1, kappa2, psi2]

    if any(~isfinite(Q))
        nll = 1e12;
        return
    end

    vnorm = Q(1);
    eta = Q(2);
    a = Q(3);
    ter = Q(4);
    st = Q(5);
    kappa1 = Q(6);
    psi1 = Q(7);
    kappa2 = Q(8);
    psi2 = Q(9);

    P1 = [vnorm, kappa1, eta, psi1, a, ter, st];
    P2 = [vnorm, kappa2, eta, psi2, a, ter, st];

    d1 = d(d.cond == 1, :);
    d2 = d(d.cond == 2, :);

    nll1 = jpcdm_nll(P1, d1, tmax);
    nll2 = jpcdm_nll(P2, d2, tmax);

    nll = nll1 + nll2;
end
