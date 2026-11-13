function [resultFile, record] = re2024_result_file(route)
%RE2024_RESULT_FILE Resolve a canonical result from the explicit manifest.
%   Accepts the existing H label or the descriptive route_id. Never selects
%   by timestamp or wildcard; original and corrected files may coexist.
    thisDir = fileparts(mfilename('fullpath'));
    manifestFile = fullfile(thisDir, 'results_manifest.csv');
    records = readtable(manifestFile, 'TextType', 'string', ...
        'Delimiter', ',', 'ReadVariableNames', true, 'VariableNamingRule', 'preserve');
    route = string(route);
    if ~isscalar(route)
        error('re2024_result_file:InvalidRoute', 'Provide one route name.');
    end
    selected = records.canonical == 1 & ...
        (strcmpi(records.alias, route) | strcmpi(records.route_id, route));
    if sum(selected) ~= 1
        error('re2024_result_file:UnknownRoute', ...
            'Expected one canonical manifest record for %s; found %d.', ...
            route, sum(selected));
    end
    record = records(selected, :);
    resultFile = fullfile(thisDir, record.fit_file);
    if ~isfile(resultFile)
        error('re2024_result_file:MissingFile', ...
            'Canonical result is missing: %s.', resultFile);
    end
end
