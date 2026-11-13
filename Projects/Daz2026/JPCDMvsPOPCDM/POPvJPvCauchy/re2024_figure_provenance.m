function re2024_figure_provenance(outDir, routes, generator)
%RE2024_FIGURE_PROVENANCE Record exact saved-fit sources used by a plotter.
    routes = string(routes);
    records = table();
    for i = 1:numel(routes)
        [~, record] = re2024_result_file(routes(i));
        records = [records; record]; %#ok<AGROW>
    end
    records.generator = repmat(string(generator), height(records), 1);
    records.generated_at = repmat(string(datetime('now', ...
        'Format', 'yyyy-MM-dd HH:mm:ss')), height(records), 1);
    writetable(records, fullfile(outDir, 'result_provenance.csv'));
end
