function output = plot_re2024_qvwm()
%PLOT_RE2024_QVWM Export participant-level QVWM plots for Cauchy H0/H1/H2.
%   Uses saved Pred fields, so no model likelihoods are recomputed. Outputs
%   H0_AQ.png, H1_eta_AQ.png, H1_vnorm_AQ.png, H1_ter_AQ.png, and
%   H2_tsensitive_AQ.png (and corresponding participant files).

    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir, '-begin');
    dataFile = fullfile(thisDir, 'Re2024_POPvJPvCauchy_prepared.mat');
    outDir = fullfile(thisDir, 'Figures', 'Re2024_QVWM');
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    prepared = load(dataFile, 'Data', 'participantIDs', 'condLevels');
    DataAll = prepared.Data;
    participantIDs = string(prepared.participantIDs);
    condLevels = string(prepared.condLevels);

    routes = struct( ...
        'tag', {"H0", "H1_eta", "H1_vnorm", "H1_ter", "H2_tsensitive"}, ...
        'folder', {"H0_kappaCell_sharedDecision", "H1_eta", ...
                   "H1_vnorm", "H1_ter", "H2_tsensitive"}, ...
        'pattern', {"H0_kappaCell_sharedDecision_*.mat", "H1_eta_*.mat", ...
                    "H1_vnorm_*.mat", "H1_ter_*.mat", "H2_tsensitive_*.mat"});

    figureFiles = strings(0, 1);
    for r = 1:numel(routes)
        fitDir = fullfile(thisDir, 'TestFits', routes(r).folder);
        resultFile = local_one_result_file(fitDir, routes(r).pattern);
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

    output = struct();
    output.outputDirectory = string(outDir);
    output.figureFiles = figureFiles;
    output.routes = string({routes.tag});
    output.participantIDs = participantIDs;
    fprintf('Saved %d QVWM figures in:\n%s\n', numel(figureFiles), outDir);
end

function resultFile = local_one_result_file(fitDir, pattern)
    files = dir(fullfile(fitDir, pattern));
    files = files(~startsWith({files.name}, 'checkpoint_'));
    if numel(files) ~= 1
        error('plot_re2024_qvwm:ResultFile', ...
            'Expected one aggregate result matching %s in %s; found %d.', ...
            pattern, fitDir, numel(files));
    end
    resultFile = fullfile(files(1).folder, files(1).name);
end
