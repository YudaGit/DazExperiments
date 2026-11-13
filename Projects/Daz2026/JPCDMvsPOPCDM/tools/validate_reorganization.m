function validate_reorganization()
%VALIDATE_REORGANIZATION Exercise path selection, data replay and plot replay.
%   Does not build MEX, call likelihoods or start optimization.
    root = fileparts(fileparts(mfilename('fullpath')));
    active = fullfile(root, 'POPvJPvCauchy');
    addpath(active, '-begin');
    files = ["re2024_result_file", "re2024_figure_provenance", ...
        "prepareRe2024Data", "plot_re2024_qvwm", ...
        "plot_re2024_h1_marginals", "plot_re2024_besth1_h2ts_marginals"];
    for name = files
        issues = checkcode(fullfile(active, name + ".m"), '-id');
        assert(~any(strcmp({issues.id}, 'PARSE')), 'MATLAB parse error: %s', name);
    end
    manifest = readtable(fullfile(active, 'results_manifest.csv'), 'TextType', 'string', ...
        'Delimiter', ',', 'ReadVariableNames', true, 'VariableNamingRule', 'preserve');
    assert(height(manifest) == 11);
    for i = 1:height(manifest)
        a = re2024_result_file(manifest.alias(i));
        b = re2024_result_file(manifest.route_id(i));
        assert(strcmp(a, b) && isfile(a));
    end
    h2 = re2024_result_file('H2_tsensitive');
    assert(endsWith(h2, 'H2_tsensitive_20260929_AQH3warm_merged.mat'));
    try
        re2024_result_file('invalid_route_for_check');
        error('validation:ExpectedFailure', 'Unknown route was accepted.');
    catch ME
        assert(strcmp(ME.identifier, 're2024_result_file:UnknownRoute'));
    end
    before = load(fullfile(active, 'Re2024_POPvJPvCauchy_prepared.mat'), 'Data');
    [data, ~, ~, ~, counts] = prepareRe2024Data([], [], false);
    assert(isequaln(data, before.Data), 'Raw data replay differs from prepared snapshot.');
    assert(isequal(sum(counts, 2)', [4488 4488 4495 4492 4497]));
    set(groot, 'defaultFigureVisible', 'off');
    plots = {@plot_re2024_h1_marginals, @plot_re2024_besth1_h2ts_marginals, @plot_re2024_qvwm};
    for i = 1:numel(plots)
        output = plots{i}();
        assert(all(isfile(output.figureFiles)));
        assert(isfile(fullfile(output.outputDirectory, 'result_provenance.csv')));
        fprintf('Verified %s: %d exported figures.\n', func2str(plots{i}), numel(output.figureFiles));
    end
    fprintf('Reorganization validation passed: 11 routes, exact data replay, 35 plots.\n');
end
