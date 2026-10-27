function figureHandles = plot_saved_popcdm_results(resultFile)
%PLOT_SAVED_POPCDM_RESULTS Recreate diagnostics without refitting POPCDM.
%   plot_saved_popcdm_results("pop_fit_9k3v3ter_results.mat")

    arguments
        resultFile (1,1) string = ""
    end
    
    if strlength(resultFile)==0
        [fileName,pathName] = uigetfile('*.mat','Select saved POPCDM results');
        if isequal(fileName,0)
            figureHandles = gobjects(0);
            return
        end
        resultFile = string(fullfile(pathName,fileName));
    end

    if ~isfile(resultFile)
        error('POPCDM:ResultFileNotFound', ...
            'Saved result file was not found: %s',resultFile);
    end

    saved = load(resultFile);
    if isfield(saved,'fitResultKappaCond')
        fitResults = saved.fitResultKappaCond;
        modelShortName = "9k3v";
    elseif isfield(saved,'fitResultAlphaCond')
        fitResults = saved.fitResultAlphaCond;
        modelShortName = "9a3v";
    else
        error('Result file contains neither POPCDM fit result structure.');
    end

    if isfield(saved,'condLevels')
        condLevels = saved.condLevels;
    else
        condLevels = ["S2C2NR","S4C2NR","S4C2R", ...
            "S4C4NR","S6C2NR","S6C2R", ...
            "S6C4NR","S6C4R","S6C6NR"];
    end
    tmax = get_saved_or_default(saved,'tmax',3.0);
    nw = get_saved_or_default(saved,'nw',50);
    h = get_saved_or_default(saved,'h',tmax/300);

    dataFile = ['/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/' ...
        'Redundancy 2024/Modelling/POPCDM/DazPreprocessed.csv'];
    d = prepare_behavioral_data(dataFile,string({fitResults.uid}),condLevels);

    figureHandles = gobjects(2*numel(fitResults),1);
    for p = 1:numel(fitResults)
        uid = string(fitResults(p).uid);
        dp = d(d.uid==uid,:);
        [angleFigure,rtFigure] = plot_one_participant( ...
            uid,dp,fitResults(p).condFit,condLevels,nw,h,tmax,modelShortName);
        figureHandles(2*p-1) = angleFigure;
        figureHandles(2*p) = rtFigure;
    end
end

function value = get_saved_or_default(saved,fieldName,defaultValue)
    if isfield(saved,fieldName)
        value = saved.(fieldName);
    else
        value = defaultValue;
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
        uid,dp,condFit,condLevels,nw,h,tmax,modelShortName)
    nCond = numel(condLevels);
    thetaDeg = cell(nCond,1);
    angleDensityDeg = cell(nCond,1);
    modelT = cell(nCond,1);
    rtDensity = cell(nCond,1);
    angleEdges = -180:5:180;
    rtEdges = 0.3:0.025:3.0;

    for c = 1:nCond
        P = [condFit.Vnorm(c),condFit.Eta1(c),condFit.Eta2(c), ...
             condFit.A(c),condFit.Alpha(c),condFit.Kappa(c), ...
             condFit.Ter(c),condFit.St(c)];
        [T,Gt,Theta] = popcdm2(P,nw,h,tmax);

        tInterior = T(1:end-1);
        gtInterior = max(Gt(:,1:end-1),0);
        dtheta = Theta(2)-Theta(1);
        dt = tInterior(2)-tInterior(1);
        retainedTime = tInterior>=0.3 & tInterior<=3.0;
        gtSelected = gtInterior(:,retainedTime);
        gtSelected = gtSelected/(sum(gtSelected,'all')*dtheta*dt);

        thetaDeg{c} = [Theta,pi]*180/pi;
        angleDensityRad = sum(gtSelected,2)*dt;
        angleDensityDeg{c} = [angleDensityRad;angleDensityRad(1)].'*pi/180;
        modelT{c} = tInterior(retainedTime);
        rtDensity{c} = sum(gtSelected,1)*dtheta;
    end

    angleFigure = figure('Name',char(uid+" POPCDM "+modelShortName+" saved angle diagnostics"));
    tiledlayout(3,3);
    sgtitle(uid+" POPCDM "+modelShortName+" response-error distributions");
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

    rtFigure = figure('Name',char(uid+" POPCDM "+modelShortName+" saved RT diagnostics"));
    tiledlayout(3,3);
    sgtitle(uid+" POPCDM "+modelShortName+" RT distributions");
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
