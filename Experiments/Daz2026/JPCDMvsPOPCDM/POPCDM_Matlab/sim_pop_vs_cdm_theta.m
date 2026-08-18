function sim_pop_vs_cdm_theta
%SIM_POP_VS_CDM_THETA  POP spike vs CDM smearing of response angle.
%
% Edit the parameter block and run this file. Three densities are overlaid:
%   1. POP layer   — drift-angle distribution from LCM Gumbel-max
%   2. CDM kernel  — response angle given an exact drift at 0 (delta encoding)
%   3. POPCDM mix  — full model, i.e. CDM mixed over the POP drift distribution
%
% At high alpha and kappa, (1) is a spike but (3) still looks like (2).
% ter and st do not enter the angle marginal.

%% -------- edit these ----------------------------------------------------
vnorm = 10.0;          % drift-rate norm
eta1  = 0.50;         % radial drift variability (lb 0.01)
eta2  = 0.0001;       % tangential; theory fits fix this
a     = 10.0;          % circular barrier
alpha = 7;            % POP amplitude: 5 ~ popSS, 60 ~ A2 popcdm, 300 ~ near-delta
kappa = 10;           % POP concentration (try 4 vs 30)
ter   = 0.15;         % unused for P(theta); required by popcdm2
st    = 0.10;

nw    = 50;           % same grid as the fitter; raise to 100 for a smoother plot
tmax  = 3.0;
h     = tmax / 300;
%% -----------------------------------------------------------------------

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

eta1 = max(eta1, 0.01);
eta2 = max(eta2, exp(-6));
sigma = 1.0;
w = 2 * pi / nw;

% POP drift-angle PMF (same LCM as nested popcode in popcdm2).
[Theta, pang] = lcm_popcode(alpha, kappa, nw);
popDensity = pang / w;

% CDM kernel: response angle given drift exactly at 0.
[~, ~, ThetaCdm, cdmDensity] = cdm([vnorm, 0, eta1, eta2, sigma, a], nw, h, tmax);
if max(abs(ThetaCdm - Theta)) > 1e-12
    error('CDM and POP angle grids do not match.');
end
cdmDensity = renormalize_density(cdmDensity, w);

% Full POPCDM mixture.
P = [vnorm, eta1, eta2, a, alpha, kappa, ter, st];
[~, ~, ThetaMix, mixDensity] = popcdm2(P, nw, h, tmax);
if max(abs(ThetaMix - Theta)) > 1e-12
    error('POPCDM and POP angle grids do not match.');
end
mixDensity = renormalize_density(mixDensity, w);

deg = Theta * 180 / pi;
popStats = circular_stats(Theta, popDensity, w);
cdmStats = circular_stats(Theta, cdmDensity, w);
mixStats = circular_stats(Theta, mixDensity, w);
floorWeight = lcm_floor_weight(alpha, kappa, nw);

vmOnlySdDeg = von_mises_sd_deg(kappa);
print_report(vnorm, eta1, eta2, a, alpha, kappa, nw, ...
    popStats, cdmStats, mixStats, floorWeight, vmOnlySdDeg);

% Cartesian overlay.
figure('Name', 'POP vs CDM theta', 'Color', 'w', 'Position', [80 80 1100 420]);
subplot(1, 2, 1);
hold on;
plot(deg, popDensity, 'LineWidth', 2.2);
plot(deg, cdmDensity, 'LineWidth', 2.2);
plot(deg, mixDensity, '--', 'LineWidth', 1.8);
hold off;
grid on;
xlim([-180, 180]);
xlabel('theta (deg)');
ylabel('density');
title('Angle densities');
legend({sprintf('POP drift  (circ SD = %.1f deg)', popStats.sdDeg), ...
        sprintf('CDM | drift=0  (circ SD = %.1f deg)', cdmStats.sdDeg), ...
        sprintf('POPCDM response  (circ SD = %.1f deg)', mixStats.sdDeg)}, ...
    'Location', 'northwest');

% Polar overlay (radius = density).
subplot(1, 2, 2);
polarplot([Theta, Theta(1)], [popDensity, popDensity(1)], 'LineWidth', 2.2);
hold on;
polarplot([Theta, Theta(1)], [cdmDensity, cdmDensity(1)], 'LineWidth', 2.2);
polarplot([Theta, Theta(1)], [mixDensity, mixDensity(1)], '--', 'LineWidth', 1.8);
hold off;
title('Same densities on the circle');
legend({'POP drift', 'CDM | drift=0', 'POPCDM response'}, 'Location', 'southoutside');

end

function [th, pang] = lcm_popcode(alpha, kappa, nw)
gamma = 0.5772156649;
w = 2 * pi / nw;
th = -pi:w:(pi - w);
vm = exp(kappa * cos(th));
vm = vm / (2 * pi * besseli(0, kappa));
popArray = gamma + alpha * vm;
pang = popArray / sum(popArray);
end

function weight = lcm_floor_weight(alpha, kappa, nw)
gamma = 0.5772156649;
w = 2 * pi / nw;
th = -pi:w:(pi - w);
vm = exp(kappa * cos(th));
vm = vm / (2 * pi * besseli(0, kappa));
popArray = gamma + alpha * vm;
weight = (gamma * nw) / sum(popArray);
end

function density = renormalize_density(density, w)
density = density(:)';
mass = sum(density) * w;
if ~(isfinite(mass) && mass > 0)
    error('Angle density has non-positive mass.');
end
density = density / mass;
end

function stats = circular_stats(theta, density, w)
p = density * w;
p = p / sum(p);
R = abs(sum(p .* exp(1i * theta)));
R = min(max(R, realmin), 1);
stats.sdDeg = sqrt(-2 * log(R)) * 180 / pi;
stats.mass10 = local_mass(theta, p, 10);
stats.mass20 = local_mass(theta, p, 20);
stats.mass45 = local_mass(theta, p, 45);
end

function m = local_mass(theta, p, halfWidthDeg)
m = sum(p(abs(theta) <= halfWidthDeg * pi / 180));
end

function sdDeg = von_mises_sd_deg(kappa)
R = besseli(1, kappa) / besseli(0, kappa);
R = min(max(R, realmin), 1);
sdDeg = sqrt(-2 * log(R)) * 180 / pi;
end

function print_report(vnorm, eta1, eta2, a, alpha, kappa, nw, ...
        popStats, cdmStats, mixStats, floorWeight, vmOnlySdDeg)
fprintf('\nPOPCDM angle decomposition\n');
fprintf('  vnorm=%.3g  eta1=%.3g  eta2=%.3g  a=%.3g  sigma=1\n', ...
    vnorm, eta1, eta2, a);
fprintf('  alpha=%.3g  kappa=%.3g  nw=%d\n', alpha, kappa, nw);
fprintf('  von Mises-only circ SD (no Gumbel floor) = %.1f deg\n', vmOnlySdDeg);
fprintf('  LCM uniform-floor weight = %.3f  (high alpha drives this toward 0)\n\n', ...
    floorWeight);
fprintf('  %-18s %10s %10s %10s %10s\n', ...
    '', 'circ SD', 'P(|th|<10)', 'P(|th|<20)', 'P(|th|<45)');
fprintf('  %-18s %8.1f deg %10.3f %10.3f %10.3f\n', ...
    'POP drift', popStats.sdDeg, popStats.mass10, popStats.mass20, popStats.mass45);
fprintf('  %-18s %8.1f deg %10.3f %10.3f %10.3f\n', ...
    'CDM | drift=0', cdmStats.sdDeg, cdmStats.mass10, cdmStats.mass20, cdmStats.mass45);
fprintf('  %-18s %8.1f deg %10.3f %10.3f %10.3f\n\n', ...
    'POPCDM response', mixStats.sdDeg, mixStats.mass10, mixStats.mass20, mixStats.mass45);
fprintf(['  The CDM kernel does not depend on alpha or kappa. If POP is a\n' ...
         '  spike and POPCDM still matches that kernel, the error tail is\n' ...
         '  coming from circular diffusion, not from encoding.\n']);
end
