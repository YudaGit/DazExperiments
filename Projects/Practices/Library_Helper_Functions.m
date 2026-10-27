% Helper functions for continuous-report experiments
% (stimulus layout, trial-matrix generation, drawing routines, response
%  collection, saving, plotting).
%
% Nothing in this file runs by itself.  Each sub-function is public, e.g.
%
%   P      = cr_defaultParams(screenRect);
%   M      = cr_buildTrialMatrix(P, 200);      % 200 trials
%   xy     = cr_ringCoords(6, P.center, P.layout.radius);
%   wheelT = cr_makeColorWheelTexture(win, P);
%==========================================================================

% ────────────────────────────────────────────────────────────────────────────────────

