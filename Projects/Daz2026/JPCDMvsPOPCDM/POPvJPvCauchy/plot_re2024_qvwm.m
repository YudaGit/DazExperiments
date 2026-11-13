function output = plot_re2024_qvwm(outDir)
%PLOT_RE2024_QVWM Export participant-level QVWM plots for Cauchy H0/H1/H2.
%   Uses saved Pred fields, so no model likelihoods are recomputed. Outputs
%   H0_AQ.png, H1_eta_AQ.png, H1_vnorm_AQ.png, H1_ter_AQ.png, and
%   H2_tsensitive_AQ.png (and corresponding participant files).

    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir, '-begin');
    dataFile = fullfile(thisDir, 'Re2024_POPvJPvCauchy_prepared.mat');
    if nargin < 1 || isempty(outDir)
        outDir = fullfile(thisDir, 'Figures', 'Exploratory', 'Replays', ...
            char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')), mfilename);
    end
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    prepared = load(dataFile, 'Data', 'participantIDs', 'condLevels');
    DataAll = prepared.Data;
    participantIDs = string(prepared.participantIDs);
    condLevels = string(prepared.condLevels);

    routes = struct('tag', {"H0", "H1_eta", "H1_vnorm", ...
        "H1_ter", "H2_tsensitive"});

    figureFiles = strings(0, 1);
    for r = 1:numel(routes)
        resultFile = re2024_result_file(routes(r).tag);
        loaded = load(resultFile, 'allResults');

        for p = 1:numel(participantIDs)
            uid = participantIDs(p);
            fieldName = matlab.lang.makeValidName(char(uid + "_cauchy"));
            if ~isfield(loaded.allResults, fieldName)
                error('plot_re2024_qvwm:MissingParticipant', ...
                    '%s is missing from %s.', uid, resultFile);
            end
            result = loaded.allResults.(fieldName);
            if ~isfield(result, 'Pred') || isempty(result.Pred)
                error('plot_re2024_qvwm:MissingPredictions', ...
                    '%s does not contain saved predictions for %s.', resultFile, uid);
            end

            fig = qvwm_ydl26(result.Pred, [], [], [], DataAll(p, :), ...
                [0.5, 2.8], condLevels);
            sgtitle(fig, sprintf('%s: %s Cauchy RT quantiles by response error', ...
                uid, routes(r).tag), 'Interpreter', 'none');
            outputFile = fullfile(outDir, char(routes(r).tag + "_" + uid + ".png"));
            exportgraphics(fig, outputFile, 'Resolution', 220);
            close(fig);
            figureFiles(end + 1, 1) = string(outputFile); %#ok<AGROW>
        end
    end

    re2024_figure_provenance(outDir, string({routes.tag}), mfilename);
    output = struct();
    output.outputDirectory = string(outDir);
    output.figureFiles = figureFiles;
    output.routes = string({routes.tag});
    output.participantIDs = participantIDs;
    fprintf('Saved %d QVWM figures in:\n%s\n', numel(figureFiles), outDir);
end
