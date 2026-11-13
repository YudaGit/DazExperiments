function plot_saved_cauchycdm_results(resultFile,targetUIDs)
%PLOT_SAVED_CAUCHYCDM_RESULTS Recreate angle/RT diagnostics without refit.

    arguments
        resultFile (1,1) string = fullfile('CauchyFits','cauchycdm_H0_full_results.mat')
        targetUIDs (1,:) string = strings(1,0)
    end
    thisDir=fileparts(mfilename('fullpath'));
    if ~isfile(resultFile), resultFile=fullfile(thisDir,resultFile); end
    S=load(resultFile);
    ids=string({S.fitResults.uid});
    if ~isempty(targetUIDs), keep=ismember(ids,targetUIDs); else, keep=true(size(ids)); end
    dataFile=fullfile('C:\Users\Yuda\Documents\GitHub\DazExperiments\Data', ...
        'Redundancy 2024','DazPreprocessed.csv');
    d=prepare_plot_data(dataFile,ids(keep),S.model.condLevels);
    outputDir=fullfile(thisDir,'Figures','H0');
    for p=find(keep)
        uid=string(S.fitResults(p).uid);
        dp=d(d.uid==uid,:);
        cauchycdm_diagnostics(uid,dp,S.fitResults(p).condFit, ...
            S.model.condLevels,S.tmax,outputDir);
    end
end

function d=prepare_plot_data(dataFile,targetIDs,condLevels)
    d=readtable(dataFile); d.uid=string(d.uid);
    d=d(ismember(d.uid,targetIDs),:); d=d(~ismissing(d.response_error),:);
    d=d(d.response_RT>=300&d.response_RT<=3000,:);
    ni=nan(height(d),1); ni(string(d.num_items)=="Two Items")=2;
    ni(string(d.num_items)=="Four Items")=4; ni(string(d.num_items)=="Six Items")=6;
    nc=nan(height(d),1); nc(string(d.ColorN)=="One Color")=1;
    nc(string(d.ColorN)=="Two Colors")=2; nc(string(d.ColorN)=="Four Colors")=4;
    nc(string(d.ColorN)=="Six Colors")=6;
    red=strings(height(d),1); red(string(d.redundancy)=="Non-Redundant Cued")="NR";
    red(red=="")="R"; d.Cond="S"+string(ni)+"C"+string(nc)+red;
    [known,d.condIdx]=ismember(d.Cond,condLevels);
    if any(~known),error('Unexpected condition.');end
    d.rAngle=d.response_error*pi/180; d.rt=d.response_RT/1000;
end
