% =========================================================================
% Validate and benchmark the vectorized/cached POPCDM MATLAB implementation
% =========================================================================

clear; clc;

% Clearing the functions also clears their persistent Bessel-root caches.
% This makes the first timing include root calculation, while the second
% timing shows the normal cached runtime used during model fitting.
clear popcdm2 cdm besselzero;

% -------------------------------------------------------------------------
% 1. Validate the Bessel roots required by dhamana
% -------------------------------------------------------------------------
J0k = besselzero(0, 50, 1);
rootResidual = max(abs(besselj(0, J0k)));

assert(numel(J0k) == 50, 'Expected 50 J_0 roots.');
assert(all(diff(J0k) > 0), 'Bessel roots must be strictly increasing.');
assert(rootResidual < 1e-10, ...
    'Bessel-root residual is too large: %.3g', rootResidual);

% -------------------------------------------------------------------------
% 2. Evaluate POPCDM twice using the same parameters
% -------------------------------------------------------------------------
% P = [vnorm, eta1, eta2, a, alpha, kappa, ter, st]
P = [2.5, 0.30, 0.02, 2.0, 2.0, 20.0, 0.30, 0.20];
nw = 50;
tmax = 3.0;
h = tmax / 300;

firstTimer = tic;
[T1, Gt1, Theta1, Ptheta1, Mt1] = popcdm2(P, nw, h, tmax);
firstCallSeconds = toc(firstTimer);

secondTimer = tic;
[T2, Gt2, Theta2, Ptheta2, Mt2] = popcdm2(P, nw, h, tmax);
secondCallSeconds = toc(secondTimer);

% -------------------------------------------------------------------------
% 3. Check output shape, validity, and deterministic equality
% -------------------------------------------------------------------------
assert(isequal(size(Gt1), [nw, numel(T1)]), ...
    'Gt has an unexpected shape.');
assert(numel(Theta1) == nw, 'Theta should contain nw values.');
assert(all(isfinite(Gt1), 'all'), 'Gt contains non-finite values.');
assert(all(Gt1 >= 0, 'all'), 'Gt contains negative density values.');

maxGtDifference = max(abs(Gt1 - Gt2), [], 'all');
maxPthetaDifference = max(abs(Ptheta1 - Ptheta2), [], 'all');
maxMtDifference = max(abs(Mt1 - Mt2), [], 'all');

assert(isequal(T1, T2) && isequal(Theta1, Theta2), ...
    'Repeated calls produced different grids.');
assert(maxGtDifference < 1e-12, ...
    'Repeated calls changed Gt by %.3g.', maxGtDifference);
assert(maxPthetaDifference < 1e-12, ...
    'Repeated calls changed Ptheta by %.3g.', maxPthetaDifference);
assert(maxMtDifference < 1e-12, ...
    'Repeated calls changed Mt by %.3g.', maxMtDifference);

% Approximate mass captured by the finite angle-time grid. It need not be
% exactly one because the time grid truncates the model distribution.
dtheta = Theta1(2) - Theta1(1);
dt = T1(2) - T1(1);
capturedMass = sum(Gt1, 'all') * dtheta * dt;

fprintf('Bessel-root maximum residual: %.3g\n', rootResidual);
fprintf('Gt size: %d angles x %d time points\n', size(Gt1, 1), size(Gt1, 2));
fprintf('Approximate captured joint-density mass: %.8f\n', capturedMass);
fprintf('First call (builds caches): %.6f seconds\n', firstCallSeconds);
fprintf('Second call (uses caches): %.6f seconds\n', secondCallSeconds);
fprintf('Cached-call speed ratio: %.2fx\n', firstCallSeconds / secondCallSeconds);
fprintf('POPCDM validation completed successfully.\n');
