function output = smoke_test_cauchy_hypotheses()
%SMOKE_TEST_CAUCHY_HYPOTHESES Check all Cauchy layouts without fitting.
%   Evaluates each route at its stated initial vector for AQ. A finite
%   likelihood confirms the parameter layout and condition mapping agree
%   between test_fit_re2024 and test_ylcauchy.

    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir, '-begin');
    build_test_mex();
    [DataAll, condLevels, ~, participantIDs] = prepareRe2024Data( ...
        [], ["AQ", "ES", "HC", "PG", "YL"], false);

    hypotheses = ["H0", "H1_ETA", "H1_VNORM", "H1_TER", ...
        "H1_VNORM_SN", "LEGACY_ETA_CELL_VNORM_SN"];
    rows = table();
    for h = hypotheses
        spec = re2024_cauchy_hypothesis_spec(h, condLevels);
        nll = test_ylcauchy(spec.P0, [], true(size(spec.P0)), DataAll(1, :), 0, h);
        if ~isfinite(nll)
            error('smoke_test_cauchy_hypotheses:NonFiniteNLL', ...
                '%s returned a non-finite NLL.', h);
        end
        rows = [rows; table(h, numel(spec.P0), nll, ...
            'VariableNames', {'hypothesis', 'nFree', 'initialNLL'})]; %#ok<AGROW>
    end
    disp(rows);
    output = struct('participant', participantIDs(1), 'summary', rows);
end
