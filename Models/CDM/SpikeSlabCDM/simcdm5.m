function [x, t, rx, tx, trx] = simcdm5(P, tmax, ntrials, trace)
%SIMCDM5  Spike-and-slab 2D diffusion simulator (random walk), circular boundary.
%
%   [x, t, rx, tx, trx] = simcdm5(P, tmax, ntrials)
%   [x, t, rx, tx, trx] = simcdm5(P, tmax, ntrials, trace)
%
%   Each trial mixes two drift regimes with probability q ("spike") vs 1-q ("slab"):
%   - Spike: drift mean ~ (vnorm, 0) plus Gaussian variability (eta1 radial, eta2 tangential).
%   - Slab: drift has norm vnorm and uniformly random direction on [-pi, pi].
%
%   P = [vnorm, eta1, eta2, a, Ter, st, q]
%        radial/tangential variability names match slabcdmsim3 (etar = eta1, etat = eta2).
%
%   Outputs:
%     x    — angle grid used internally (length nw = 73), linspace(-pi, pi, nw)
%     t    — decision-time grid (seconds), excludes Ter (Ter added into tx)
%     rx   — 1 x ntrials response angles (radians), atan2 at boundary crossing
%     tx   — 1 x ntrials RTs including non-decision (seconds)
%     trx  — ntrials x 2, [rx(:), tx(:)] for KDE / histograms
%
%   sigma is fixed at 1; step size h = 0.01 s. Set rng before calling for reproducibility.
%
%   See also: slabcdmsim3, cdmsimll5 (in slabcdmsim3.m).

    if nargin < 4
        trace = 0;
    end

    vnorm = P(1);
    eta1 = P(2);
    eta2 = P(3);
    a = P(4);
    ter = P(5);
    st = P(6);
    q = P(7);
    sigma = 1.0; % Standard scaling

    h = .01; % 10 ms steps
    ns = tmax / h;
    nw = 73; % Like scdm3 without the padding
    x = linspace(-pi, pi, nw); % same as scdm - wrap around at left end
    rx = zeros(1, ntrials);
    tx = zeros(1, ntrials);
    trx = zeros(ntrials, 2); % ksdensity wants two columns
    t = [1:ns]*h;
    a = a - sigma * sqrt(h) / 2; % Overshoot correction for random walk

    % Simulate ntrials
    n_terminated = 0;
    Ter = st * (rand(1, ntrials) - 0.5) + ter; % Vector of random Ter values
    MuSpike = [vnorm + eta1 * randn(1, ntrials);  eta2 * randn(1, ntrials)]; % Matrix of random drift rate components
    SlabAngle = (2 * pi - 0.0) * rand(1, ntrials) - pi;
    MuSlab = [vnorm * cos(SlabAngle); vnorm * sin(SlabAngle)];
    Q = rand(1,ntrials) < q;
    Mu = Q .* MuSpike + (1 - Q) .* MuSlab;  % Mixture of spike and slab with mixing proportion q.
    a2 = a * a;
    nmax = floor(tmax/h);
    % allocate space once
    Xt = zeros(2, nmax);
    for j = 1:ntrials
        Xt(1,:) = 0; % reinitialize
        Mut = [Mu(1,j) * ones(1,nmax); Mu(2,j) * ones(1, nmax)]; % Mut has eta variability across trials
        Sigma_Wt = [sigma * randn(1,nmax); sigma * randn(1,nmax)];
        Dt2 = 0; % squared distance
        i = 2;
        while(Dt2 < a2 && i <= nmax)
            Xt(:,i) =  Xt(:,i-1) + Mut(:,i) * h + Sigma_Wt(:,i) * sqrt(h);
            Dt2 = Xt(1, i)^2 + Xt(2, i)^2;
            i = i + 1;
        end
        athetaj = atan2(Xt(2, i-1), Xt(1,i-1));  % angle of first two components.
        rx(j) = athetaj;
        tx(j) = (i-1) * h + Ter(j); % add uniform ter to decision time
        trx(j,1) = rx(j);  % Joint density pairs.
        trx(j,2) = tx(j);
        if trace
            terminating_step = i;
            terminating_time = tx(j);
        end
        n_terminated = n_terminated + 1;
    end
    if trace
        n_terminated = n_terminated + 1;
    end
end
