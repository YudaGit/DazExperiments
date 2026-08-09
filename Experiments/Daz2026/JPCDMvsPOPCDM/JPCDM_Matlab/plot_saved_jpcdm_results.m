function figureHandles = plot_saved_jpcdm_results(resultFile)
%PLOT_SAVED_JPCDM_RESULTS Recreate diagnostics without refitting JPCDM.
%   plot_saved_jpcdm_results("jp_fit_9k3v3ter_results.mat")
%   plot_saved_jpcdm_results() opens a file chooser for the result file.
%
% The saved fit structures contain the fitted condition-level parameters.
% This function reloads and filters the original behavioral data, then
% reconstructs the same normalized model marginals used by the likelihood.

    arguments
        resultFile (1,1) string = ""
    end

    if strlength(resultFile)==0
        [fileName,pathName] = uigetfile('*.mat','Select saved JPCDM results');
        if isequal(fileName,0)
            figureHandles = gobjects(0);
            return
        end
        resultFile = string(fullfile(pathName,fileName));
    end

    if ~isfile(resultFile)
        error('JPCDM:ResultFileNotFound', ...
            'Saved result file was not found: %s',resultFile);
    end

    saved = load(resultFile);
    if isfield(saved,'fitResultKappaCond')
        fitResults = saved.fitResultKappaCond;
        modelShortName = "9k3v";
    elseif isfield(saved,'fitResultPsiCond')
        fitResults = saved.fitResultPsiCond;
        modelShortName = "9p3v";
    else
        error('Result file contains neither JPCDM fit result structure.');
    end

    if isfield(saved,'condLevels')
        condLevels = saved.condLevels;
    else
        condLevels = ["S2C2NR","S4C2NR","S4C2R", ...
            "S4C4NR","S6C2NR","S6C2R", ...
            "S6C4NR","S6C4R","S6C6NR"];
    end
    if isfield(saved,'tmax')
        tmax = saved.tmax;
    else
        tmax = 3.0;
    end

    dataFile = ['/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/' ...
        'Redundancy 2024/Modelling/POPCDM/DazPreprocessed.csv'];
    d = prepare_behavioral_data(dataFile, string({fitResults.uid}), condLevels);

    figureHandles = gobjects(2*numel(fitResults),1);
    for p = 1:numel(fitResults)
        uid = string(fitResults(p).uid);
        dp = d(d.uid==uid,:);
        [angleFigure,rtFigure] = plot_one_participant( ...
            uid,dp,fitResults(p).condFit,condLevels,tmax,modelShortName);
        figureHandles(2*p-1) = angleFigure;
        figureHandles(2*p) = rtFigure;
    end
end

function d = prepare_behavioral_data(dataFile,targetIDs,condLevels)
    d = readtable(dataFile);
    d.uid = string(d.uid);
    d = d(ismember(d.uid,targetIDs),:);
    d = d(~ismissing(d.response_error),:);
    d = d(d.response_RT>=300 & d.response_RT<=3000,:);

    nItems = nan(height(d),1);
    nItems(string(d.num_items)=="Two Items") = 2;
    nItems(string(d.num_items)=="Four Items") = 4;
    nItems(string(d.num_items)=="Six Items") = 6;

    nColors = nan(height(d),1);
    nColors(string(d.ColorN)=="One Color") = 1;
    nColors(string(d.ColorN)=="Two Colors") = 2;
    nColors(string(d.ColorN)=="Four Colors") = 4;
    nColors(string(d.ColorN)=="Six Colors") = 6;

    redundancyLabel = strings(height(d),1);
    redundancyLabel(string(d.redundancy)=="Non-Redundant Cued") = "NR";
    redundancyLabel(redundancyLabel=="") = "R";

    d.Cond = "S"+string(nItems)+"C"+string(nColors)+redundancyLabel;
    [known,d.condIdx] = ismember(d.Cond,condLevels);
    if any(~known)
        error('Unexpected condition while reconstructing plotting data.');
    end
    d.rAngle = d.response_error*pi/180;
    d.rt = d.response_RT/1000;
end

function [angleFigure,rtFigure] = plot_one_participant( ...
        uid,dp,condFit,condLevels,tmax,modelShortName)
    nCond = numel(condLevels);
    thetaDeg = cell(nCond,1);
    angleDensityDeg = cell(nCond,1);
    modelT = cell(nCond,1);
    rtDensity = cell(nCond,1);
    angleEdges = -180:5:180;
    rtEdges = 0.3:0.025:3.0;

    for c = 1:nCond
        if ismember('EtaRadial',condFit.Properties.VariableNames)
            eta = condFit.EtaRadial(c);
        else
            eta = condFit.Eta(c); % compatibility with earlier saved files
        end

        P = [condFit.Vnorm(c),condFit.Kappa(c),eta,condFit.Psi(c), ...
             condFit.A(c),condFit.Ter(c),condFit.St(c)];
        [T,Gt,Theta] = jpcdm1(P,tmax);

        thetaOpen = Theta(1:end-1);
        gtOpen = max(Gt(1:end-1,:),0);
        dtheta = thetaOpen(2)-thetaOpen(1);
        dt = T(2)-T(1);
        retainedTime = T>=0.3 & T<=3.0;
        gtSelected = gtOpen(:,retainedTime);
        gtSelected = gtSelected/(sum(gtSelected,'all')*dtheta*dt);

        thetaDeg{c} = [thetaOpen,pi]*180/pi;
        angleDensityRad = sum(gtSelected,2)*dt;
        angleDensityDeg{c} = [angleDensityRad;angleDensityRad(1)].'*pi/180;
        modelT{c} = T(retainedTime);
        rtDensity{c} = sum(gtSelected,1)*dtheta;
    end

    angleFigure = figure('Name',char(uid+" JPCDM "+modelShortName+" saved angle diagnostics"));
    tiledlayout(3,3);
    sgtitle(uid+" JPCDM "+modelShortName+" response-error distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx==c,:);
        nexttile;
        histogram(dc.rAngle*180/pi,'Normalization','pdf', ...
            'BinEdges',angleEdges,'FaceColor',[0.25,0.45,1.00], ...
            'FaceAlpha',0.25,'EdgeColor',[0.25,0.45,1.00]);
        hold on;
        plot(thetaDeg{c},angleDensityDeg{c},'r-','LineWidth',2);
        title(condLevels(c),'Interpreter','none');
        xlim([-180,180]);
        xlabel('Response error (deg)');
        ylabel('Density');
    end

    rtFigure = figure('Name',char(uid+" JPCDM "+modelShortName+" saved RT diagnostics"));
    tiledlayout(3,3);
    sgtitle(uid+" JPCDM "+modelShortName+" RT distributions");
    for c = 1:nCond
        dc = dp(dp.condIdx==c,:);
        nexttile;
        histogram(dc.rt,'Normalization','pdf', ...
            'BinEdges',rtEdges,'FaceColor',[0.25,0.45,1.00], ...
            'FaceAlpha',0.25,'EdgeColor',[0.25,0.45,1.00]);
        hold on;
        plot(modelT{c},rtDensity{c},'r-','LineWidth',2);
        title(condLevels(c),'Interpreter','none');
        xlim([0.3,tmax]);
        xlabel('RT (s)');
        ylabel('Density');
    end
end
