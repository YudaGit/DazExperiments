%% Continuous Color Redundancy in Visual Working Memory Recall
% Paul Garrett, Uni of Melbourne 2024/09/15. Creative Commons Licence 4SSA.
%
% Load Preprocessed Data (No Cleaning, just shaping columns in R/Python).
clear; close; clc;
cd('/Users/prefabteam_ysl/Documents/Psychology Study/HONOURS PSY/PSYC40010 Thesis/Analyses/MatLab/Matlab Results');
% Readin preprocessed file from R
data = readtable('DazPreprocessed.csv','ReadVariableNames',true);
% Remove pilot data from Daz and Paul
data = data(~ismember(data.uid, {'PGexp1', 'YLexp1'}),:);


%%
if false
    v.Model.Disp = 'iter';
else
    v.Model.Disp = 'off';
end
v.Model.LoopMaxIter = 2000;
v.Model.FunMaxIter = 10000;
v.Model.options = optimset('Display', v.Model.Disp, 'TolFun', 1e-4, 'TolX', 1e-4, ...
    'FunValCheck', 'on','MaxIter', v.Model.LoopMaxIter, 'MaxFunEvals', v.Model.FunMaxIter);

% Turn key variables into integers for easy usage in matlab
wordMap = {'One', 'Two', 'Three', 'Four', 'Five', 'Six'};
itemMap = [1,2,3,4,5,6];
data.num_itemsi = cellfun(@(x) itemMap(ismember(wordMap, regexp(x, '\w+', 'match', 'once'))), data.num_items);
data.ColorNi    = cellfun(@(x) itemMap(ismember(wordMap, regexp(x, '\w+', 'match', 'once'))), data.ColorN);
data.redundanti = strcmp(data.redundancy, 'Redundant Cued');
data.session = cellfun(@str2double, data.session);
v.rawdata = data;



%% Exclusions Table
clearvars -except v data
% We excluded missing data trials (i.e., coding issue resulted in a fraction of 
% responses that failed in calculating degrees deviated from target) and excessively 
% slow trials (i.e., RT beyond 3500ms), and 6 participants who completed only one session.

toofast = 150;
tooslow = 3500; % Daz runs 5000, I think that's too lenient.

fq = table( unique(data.uid, 'stable'), 'VariableNames', {'ID'});
fq{:,'Exp'} = 1;
fq.Exp(ismember(fq.ID, {'PG', 'ES', 'AQ', 'HC', 'YL'})) = 2;

for ii = {'Sessions','RawTrialCounts','MissingTrials','TooFast','TooSlow','CleanTrials','SessionRemoval','MixtureRemoval','Retained'}
    fq{:,ii} = nan;
end

for ii = 1:size(fq,1)
    d = data(strcmp(fq.ID{ii}, data.uid),:);
    fq.Sessions(ii) = length(unique((d.session)));
    fq.RawTrialCounts(ii) = size(d,1);
    fq.MissingTrials(ii) = sum(isnan(d.response_error));
    d = d(~isnan(d.response_error),:);
    fq.TooFast(ii) = sum(d.response_RT < toofast);
    fq.TooSlow(ii) = sum(d.response_RT >= tooslow);
    d = d(d.response_RT >= toofast & d.response_RT < tooslow,:);
    fq.CleanTrials(ii) = size(d,1);
    fq.SessionRemoval(ii) = length(unique((d.session))) == 1;
end
v.Exclusions = fq;

data = data(~isnan(data.response_error),:);
data = data(data.response_RT >= toofast & data.response_RT < tooslow,:);
data = data(~ismember(data.uid, fq.ID(fq.SessionRemoval==1)),:);
v.dataClean = data;

%% Experiment 1: Von Mises & Uniform Mixture Model with Fixed Mu = 0
clearvars -except v
data1 = v.dataClean(~ismember(v.dataClean.uid, {'PG', 'ES', 'AQ', 'HC', 'YL'}),:);
options = optimoptions('fmincon', 'Display', 'off');
% Set sizes
setSizes = [1, 2, 4, 6];

% Initial guess for the parameters: [alpha1, alpha2, alpha3, alpha4, kappa]
initialParams = [0.2, 0.3, 0.4, 0.5, 1];  % Alphas and shared kappa

% Bounds for the parameters: alpha (0 to 1), kappa (positive)
lb = [zeros(1, length(setSizes)), 0];  % Alpha bounds [0, 1], kappa >= 0
ub = [ones(1, length(setSizes)), Inf];  % Alpha bounds [0, 1], kappa upper bound 30

MixModel1 = array2table( nan(length(unique(data1.uid)) ,5), 'VariableNames',{'pUniform1','pUniform2','pUniform4','pUniform6','Kappa'});
MixModel1.ID = unique(data1.uid, 'stable');

count = 0;
for id = unique(data1.uid, 'stable')'
    count = count + 1;
    d = data1(strcmp(id, data1.uid),:);
    rad = deg2rad(d.response_error);
    
    % Separate data by set size
    dataBySetSize = { rad(d.num_itemsi == 1), ...
                      rad(d.num_itemsi == 2), ...
                      rad(d.num_itemsi == 4) ,...
                      rad(d.num_itemsi == 6)};
    
    % Minimize the negative log-likelihood for all set sizes at once
    [fittedParams, ~] = fmincon(@(params) mixtureModel(params, dataBySetSize, setSizes), ...
                                initialParams, [], [], [], [], lb, ub, [], options);
    fittedParams(1:4) = fittedParams(1:4) * 100;
    MixModel1(count,1:5) = array2table(fittedParams);
    
end
v.MixModel1 = MixModel1;
fprintf('Mixture Model 1 Complete.\n');

%% Experiment 2: Von Mises & Uniform Mixture Model with Fixed Mu = 0
clearvars -except data1 data2 v
data2 = v.dataClean(ismember(v.dataClean.uid, {'PG', 'ES', 'AQ', 'HC', 'YL'}),:);

options = optimoptions('fmincon', 'Display', 'off');
% Set sizes
setSizes = [2, 4, 6];

% Initial guess for the parameters: [alpha1, alpha2, alpha3, alpha4, kappa]
initialParams = [0.3, 0.4, 0.5, 1];  % Alphas and shared kappa

% Bounds for the parameters: alpha (0 to 1), kappa (positive)
lb = [zeros(1, length(setSizes)), 0];  % Alpha bounds [0, 1], kappa >= 0
ub = [ones(1, length(setSizes)), Inf];  % Alpha bounds [0, 1], kappa upper bound 30

MixModel2 = array2table( nan(length(unique(data2.uid)) ,4), 'VariableNames',{'pUniform2','pUniform4','pUniform6','Kappa'});
MixModel2.ID = unique(data2.uid, 'stable');

count = 0;
for id = unique(data2.uid, 'stable')'
    count = count + 1;
    d = data2(strcmp(id, data2.uid),:);
    rad = deg2rad(d.response_error);
    
    % Separate data by set size
    dataBySetSize = { rad(d.num_itemsi == 2), ...
                      rad(d.num_itemsi == 4) ,...
                      rad(d.num_itemsi == 6)};
    
    % Minimize the negative log-likelihood for all set sizes at once
    [fittedParams, ~] = fmincon(@(params) mixtureModel(params, dataBySetSize, setSizes), ...
                                initialParams, [], [], [], [], lb, ub, [], options);
    fittedParams(1:3) = fittedParams(1:3) * 100;
    MixModel2(count,1:4) = array2table(fittedParams);
    
end
v.MixModel2 = MixModel2;

% Add 1:9 condition identifiers for later use.
data2{:,'Cnd'} = 0;
data2.Cnd(data2.num_itemsi == 2) = 1;
data2.Cnd(data2.num_itemsi == 4 & data2.ColorNi == 2 & data2.redundanti == 1) = 2;
data2.Cnd(data2.num_itemsi == 4 & data2.ColorNi == 2 & data2.redundanti == 0) = 3;
data2.Cnd(data2.num_itemsi == 4 & data2.ColorNi == 4 ) = 4;
data2.Cnd(data2.num_itemsi == 6 & data2.ColorNi == 2 & data2.redundanti == 1) = 5;
data2.Cnd(data2.num_itemsi == 6 & data2.ColorNi == 2 & data2.redundanti == 0) = 6;
data2.Cnd(data2.num_itemsi == 6 & data2.ColorNi == 4 & data2.redundanti == 1) = 7;
data2.Cnd(data2.num_itemsi == 6 & data2.ColorNi == 4 & data2.redundanti == 0) = 8;
data2.Cnd(data2.num_itemsi == 6 & data2.ColorNi == 6 ) = 9;

fprintf('Mixture Model 2 Complete.\n');


%% Participant Removal via Mixture Analysis
clearvars -except data1 data2 v
% 10% and 20% estimated guessing in standard conditions of set size 1 and 2
v.MixModel1raw = v.MixModel1;
remove = v.MixModel1.ID(v.MixModel1.pUniform1 >= 10 | v.MixModel1.pUniform2 >= 20);

data1 = data1(~ismember(data1.uid, remove),:);
v.dataClean = v.dataClean(~ismember(v.dataClean.uid, remove),:);
v.MixModel1 = v.MixModel1(~ismember(v.MixModel1.ID, remove), :);

v.Exclusions.MixtureRemoval(ismember(v.Exclusions.ID, remove)) = 1;
v.Exclusions.MixtureRemoval(isnan(v.Exclusions.MixtureRemoval)) = 0;

v.Exclusions.Retained = v.Exclusions.SessionRemoval == 0 & v.Exclusions.MixtureRemoval == 0;
fprintf('Exclusions applied.\n');

%% Experiment 1: Participant Descriptives
clearvars -except data1 data2 v

fq = table( unique(data1.uid, 'stable'), 'VariableNames', {'ID'});
ids = {};
for jj = {'N1_C1r','N2_C1r','N4_C1r','N6_C1r','N2_C2','N4_C2r', 'N4_C2nr', 'N6_C2r', 'N6_C2nr', 'N4_C4','N6_C4r','N6_C4nr','N6_C6'}
    for kk = {'mRT','seRT','mPrecision','sePrecision'}
        fq{:,strcat(jj,'_',kk)} = nan;
        ids = [ids, strcat(jj,'_',kk)];
    end
end

cnds = [1,1,1; 2,1,1; 4,1,1; 6,1,1; ...
        2,2,0; 4,2,1; 4,2,0; 6,2,1; 6,2,0;...
        4,4,0; 6,4,1; 6,4,0; 6,6,0];

uid = unique(data1.uid,'stable');
for p = 1:length(uid)
    c = 1;
    for ii = 1:size(cnds,1)
        d = data1( strcmp(data1.uid, uid{p}) & data1.num_itemsi == cnds(ii,1) & data1.ColorNi == cnds(ii,2) & data1.redundanti == cnds(ii,3),:);
        fq{p,ids{c}}   = round(mean(d.response_RT));
        fq{p,ids{c+1}} = round(std(d.response_RT) / sqrt(length(d.response_RT))); 
        fq{p,ids{c+2}} = round(mean(abs(d.response_error)),2);
        fq{p,ids{c+3}} = round(rad2deg(circular_std( deg2rad( abs(d.response_error)) )) / sqrt(length(d.response_error)),2);
        c = c + 4;
    end
end
v.mdata1 = fq;
fprintf('Descriptives Experiment 1 Complete.\n');

%% Experiment 2: Participant Descriptives
clearvars -except data1 data2 v

fq = table( unique(data2.uid, 'stable'), 'VariableNames', {'ID'});
ids = {};
for jj = {'N2_C2','N4_C2r', 'N4_C2nr', 'N6_C2r', 'N6_C2nr', 'N4_C4','N6_C4r','N6_C4nr','N6_C6'}
    for kk = {'mRT','seRT','mPrecision','sePrecision'}
        fq{:,strcat(jj,'_',kk)} = nan;
        ids = [ids, strcat(jj,'_',kk)];
    end
end

cnds = [2,2,0; 4,2,1; 4,2,0; 6,2,1; 6,2,0; ...
        4,4,0; 6,4,1; 6,4,0; 6,6,0];

uid = unique(data2.uid,'stable');
for p = 1:length(uid)
    c = 1;
    for ii = 1:size(cnds,1)
        d = data2( strcmp(data2.uid, uid{p}) & data2.num_itemsi == cnds(ii,1) & data2.ColorNi == cnds(ii,2) & data2.redundanti == cnds(ii,3),:);
        fq{p,ids{c}}   = round(mean(d.response_RT));
        fq{p,ids{c+1}} = round(std(d.response_RT) / sqrt(length(d.response_RT))); 
        fq{p,ids{c+2}} = round(mean(abs(d.response_error)),2);
        fq{p,ids{c+3}} = round(rad2deg(circular_std( deg2rad(abs(d.response_error)) )) / sqrt(length(d.response_error)),2);
        c = c + 4;
    end
end
v.mdata2 = fq;
fprintf('Descriptives Experiment 2 Complete.\n');

%% Experiment 1: Response Time Plots
clearvars -except data1 data2 v

set(figure(1), 'Position', get(0, 'Screensize'), 'color','w');

uid = unique(data1.uid, 'stable');

cnds = {'N1_C1r','N2_C1r','N4_C1r','N6_C1r',...
        'N2_C2','N4_C2r', 'N4_C2nr', 'N6_C2r', 'N6_C2nr', ... 
        'N4_C4','N6_C4r','N6_C4nr',...
        'N6_C6'};

breaks = [4,9,12];
colors = [0, 239, 91; 239, 221, 0; 239, 43, 0; 0, 105, 239] / 255;

idx = [1,2,3,4,2,3,3,4,4,3,4,4,4];
trans = [1,1,1,1,.5, 1, .5, 1, .5, .5, 1, .5, .5] ;
%trans = [.66,.66,.66,.66,1, .66, 1, .66, 1, 1, .66, 1, 1] ;
border = [1,0,0,0,1,0,0,0,0,1,0,0,1];
h = {};

dotalpha = .5;
RTbins = 20;
step = .5;
offsets = repmat(-0.075:.025:0.075,1,4);
hold all;
c = 1;
for ii = 1:length(cnds)
    rt = mean(v.mdata1{:, strcat(cnds{ii},'_','mRT')});
    se = std(v.mdata1{:, strcat(cnds{ii},'_','mRT')}) ./ sqrt(size(v.mdata1,1));
    if border(ii) == 1
        h{ii} = bar(c, rt, .33, 'FaceColor', colors(idx(ii),:), 'EdgeColor', 'k', 'FaceAlpha', 1,'LineWidth',2,'EdgeAlpha',.8);
    else
        h{ii} = bar(c, rt, .33, 'FaceColor', colors(idx(ii),:), 'FaceAlpha', trans(ii),'LineWidth',2,'EdgeAlpha', 0);
    end
    errorbar(c, rt, se, 'k', 'LineWidth', 1.5); 
    c = c + step;
    if ismember(ii,breaks)
        c = c + step;
    end
end

for p = 1:length(uid)
    c = 1;
    for ii = 1:length(cnds)
        rt = v.mdata1{p, strcat(cnds{ii},'_','mRT')};
        x = c + offsets(p);
        scatter(x,rt,40,[.3,.3,.3],'linewidth',1.5,'MarkerEdgeAlpha',.25,'Marker','x');
        c = c + step;
        if ismember(ii,breaks)
            c = c + step;
        end
    end
end

ylim([0, 2000]);
xlim([step, c])
yticks(0:500:2000);
set(gca, 'linewidth', 1,'fontweight','bold','fontsize',18, 'box','off','TickLabelInterpreter','LaTeX');

xticks([1:step:5*step, step*7:step:11*step, 13*step:step:15*step, 17*step]);

xticklabels({'1','2$_R$','4$_R$','6$_R$', ...
             '2', '4$_R$', '4$_{NR}$', '6$_{R}$','6$_{NR}$', ...
             '4', '6$_R$', '6$_{NR}$', ...
             '6' });

ax = gca;
ax.Position = ax.Position + [-0.05, 0.04, 0.09, 0];
ax.XRuler.TickLength = [0 0];

text(step * 3.5, -120, '\bf 1 Color', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

text(step * 9, -120, '\bf 2 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

text(step * 14, -120, '\bf 4 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

text(step * 17, -120, '\bf 6 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

xlabel('\bf Number of Items by Number of Item Colors', 'Interpreter', 'LaTeX', 'Position', [9*step, -220]);
ylabel('\bf Response Time (ms)','Interpreter','LaTeX');

h{1} = bar(nan, nan, .33, 'FaceColor', colors(idx(1),:), 'EdgeColor', 'none', 'FaceAlpha', 1);

lgd = legend([h{1},h{2},h{3},h{4}], {'\bf 1 Item','\bf 2 Items','\bf 4 Items', '\bf 6 Items'}, ...
             'Location', 'northwest', 'Interpreter', 'LaTeX', 'box','off'); 

set(lgd, 'ItemTokenSize', [18, 20]);

title('\bf Experiment 1 Mean RT','fontsize', 20, 'Interpreter','LaTeX','Position', [9*step, 1950]);

SaveFig(gcf, fullfile('Figures', 'Exp1 Mean RT'), true, 150, [0 0 35 20] );




%% Experiment 1: Response Precision Plots
clearvars -except data1 data2 v

set(figure(1), 'Position', get(0, 'Screensize'), 'color','w');

uid = unique(data1.uid, 'stable');

cnds = {'N1_C1r','N2_C1r','N4_C1r','N6_C1r',...
        'N2_C2','N4_C2r', 'N4_C2nr', 'N6_C2r', 'N6_C2nr', ... 
        'N4_C4','N6_C4r','N6_C4nr',...
        'N6_C6'};

breaks = [4,9,12];
colors = [0, 239, 91; 239, 221, 0; 239, 43, 0; 0, 105, 239] / 255;

idx = [1,2,3,4,2,3,3,4,4,3,4,4,4];
trans = [1,1,1,1,.5, 1, .5, 1, .5, .5, 1, .5, .5] ;
%trans = [.66,.66,.66,.66,1, .66, 1, .66, 1, 1, .66, 1, 1] ;
border = [1,0,0,0,1,0,0,0,0,1,0,0,1];
h = {};

dotalpha = .5;
RTbins = 20;
step = .5;
offsets = repmat(-0.075:.025:0.075,1,4);
hold all;
c = 1;
for ii = 1:length(cnds)
    precision = mean(v.mdata1{:, strcat(cnds{ii},'_','mPrecision')});
    se = std(v.mdata1{:, strcat(cnds{ii},'_','mPrecision')}) ./ sqrt(size(v.mdata1,1));
    if border(ii) == 1
        h{ii} = bar(c, precision, .33, 'FaceColor', colors(idx(ii),:), 'EdgeColor', 'k', 'FaceAlpha', 1,'LineWidth',2,'EdgeAlpha',.8);
    else
        h{ii} = bar(c, precision, .33, 'FaceColor', colors(idx(ii),:), 'FaceAlpha', trans(ii),'LineWidth',2,'EdgeAlpha', 0);
    end
    errorbar(c, precision, se, 'k', 'LineWidth', 1.5); 
    c = c + step;
    if ismember(ii,breaks)
        c = c + step;
    end
end

for p = 1:length(uid)
    c = 1;
    for ii = 1:length(cnds)
        precision = v.mdata1{p, strcat(cnds{ii},'_','mPrecision')};
        x = c + offsets(p);
        scatter(x,precision,40,[.3,.3,.3],'linewidth',1.5,'MarkerEdgeAlpha',.25,'Marker','x');
        c = c + step;
        if ismember(ii,breaks)
            c = c + step;
        end
    end
end

%ylim([0, 2000]);
xlim([step, c])
%yticks(0:500:2000);
set(gca, 'linewidth', 1,'fontweight','bold','fontsize',18, 'box','off','TickLabelInterpreter','LaTeX');

xticks([1:step:5*step, step*7:step:11*step, 13*step:step:15*step, 17*step]);

xticklabels({'1','2$_R$','4$_R$','6$_R$', ...
             '2', '4$_R$', '4$_{NR}$', '6$_{R}$','6$_{NR}$', ...
             '4', '6$_R$', '6$_{NR}$', ...
             '6' });

ax = gca;
ax.Position = ax.Position + [-0.05, 0.04, 0.09, 0];
ax.XRuler.TickLength = [0 0];

text(step * 3.5, -6, '\bf 1 Color', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

text(step * 9, -6, '\bf 2 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

text(step * 14, -6, '\bf 4 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

text(step * 17, -6, '\bf 6 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 18, 'Interpreter', 'LaTeX');

xlabel('\bf Number of Items by Number of Item Colors', 'Interpreter', 'LaTeX', 'Position', [9*step, -10]);
ylabel('\bf Precision in Abs(Degrees Error)','Interpreter','LaTeX');

h{1} = bar(nan, nan, .33, 'FaceColor', colors(idx(1),:), 'EdgeColor', 'none', 'FaceAlpha', 1);

lgd = legend([h{1},h{2},h{3},h{4}], {'\bf 1 Item','\bf 2 Items','\bf 4 Items', '\bf 6 Items'}, ...
             'Location', 'northwest', 'Interpreter', 'LaTeX', 'box','off'); 

set(lgd, 'ItemTokenSize', [18, 20]);

title('\bf Experiment 1 Mean Abs. Precision','fontsize', 20, 'Interpreter','LaTeX','Position', [9*step, 78]);
SaveFig(gcf, fullfile('Figures', 'Exp1 Mean Abs Precision'), true, 150, [0 0 35 20] );


%% Experiment 2: Response Time Plots
clearvars -except data1 data2 v

set(figure(1), 'Position', get(0, 'Screensize'), 'color','w');

uid = unique(data2.uid, 'stable');

cnds = {'N2_C2','N4_C2r', 'N4_C2nr', 'N6_C2r', 'N6_C2nr', ... 
        'N4_C4','N6_C4r','N6_C4nr',...
        'N6_C6'};

breaks = [5,8];
colors = [0, 239, 91; 239, 221, 0; 239, 43, 0; 0, 105, 239] / 255;

idx = [2,3,3,4,4,3,4,4,4];
trans = [.5, 1, .5, 1, .5, .5, 1, .5, .5] ;
%trans = [.66,.66,.66,.66,1, .66, 1, .66, 1, 1, .66, 1, 1] ;
border = [1,0,0,0,0,1,0,0,1];
h = {};

dotalpha = .5;
RTbins = 20;
step = .5;
offsets = -0.066:.033:0.066;
hold all;
c = 1;
for ii = 1:length(cnds)
    rt = mean(v.mdata2{:, strcat(cnds{ii},'_','mRT')});
    se = std(v.mdata2{:, strcat(cnds{ii},'_','mRT')}) ./ sqrt(size(v.mdata1,1));
    if border(ii) == 1
        h{ii} = bar(c, rt, .33, 'FaceColor', colors(idx(ii),:), 'EdgeColor', 'k', 'FaceAlpha', 1,'LineWidth',2,'EdgeAlpha',.8);
    else
        h{ii} = bar(c, rt, .33, 'FaceColor', colors(idx(ii),:), 'FaceAlpha', trans(ii),'LineWidth',2,'EdgeAlpha', 0);
    end
    errorbar(c, rt, se, 'k', 'LineWidth', 1.5); 
    c = c + step;
    if ismember(ii,breaks)
        c = c + step;
    end
end

markers = {'x','s','^','+','d'};

for p = 1:length(uid)
    c = 1;
    for ii = 1:length(cnds)
        rt = v.mdata2{p, strcat(cnds{ii},'_','mRT')};
        x = c + offsets(p);
        scatter(x,rt,90,[.4,.4,.4],'linewidth',3,'MarkerEdgeAlpha',.75,'Marker',markers{p});
        c = c + step;
        if ismember(ii,breaks)
            c = c + step;
        end
    end
end

ylim([0, 2100]);
xlim([step, c])
yticks(0:500:2000);
set(gca, 'linewidth', 1,'fontweight','bold','fontsize',14, 'box','off','TickLabelInterpreter','LaTeX');

xticks([1:step:6*step, step*8:step:10*step, 12*step]);

xticklabels({'2', '4$_R$', '4$_{NR}$', '6$_{R}$','6$_{NR}$', ...
             '4', '6$_R$', '6$_{NR}$', ...
             '6' });

ax = gca;
ax.Position = ax.Position + [-0.05, 0.04, 0.09, 0];
ax.XRuler.TickLength = [0 0];

text(step * 4, -120, '\bf 2 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 14, 'Interpreter', 'LaTeX');

text(step * 9, -120, '\bf 4 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 14, 'Interpreter', 'LaTeX');

text(step * 12, -120, '\bf 6 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 14, 'Interpreter', 'LaTeX');

xlabel('\bf Number of Items by Number of Item Colors', 'Interpreter', 'LaTeX', 'Position', [7*step, -220]);
ylabel('\bf Response Time (ms)','Interpreter','LaTeX');

h{1} = bar(nan, nan, .33, 'FaceColor', colors(idx(1),:), 'EdgeColor', 'none', 'FaceAlpha', 1);

lgd = legend([h{1},h{2},h{4}], {'\bf 2 Items','\bf 4 Items', '\bf 6 Items'}, ...
             'Location', 'northwest', 'Interpreter', 'LaTeX', 'box','off'); 

set(lgd, 'ItemTokenSize', [18, 20]);

title('\bf Experiment 2 Mean RT','fontsize', 16, 'Interpreter','LaTeX','Position', [7*step, 2050]);

SaveFig(gcf, fullfile('Figures', 'Exp2 Mean RT'), true, 150, [0 0 35 20] );


%% Experiment 2: Precision Plots
clearvars -except data1 data2 v

set(figure(1), 'Position', get(0, 'Screensize'), 'color','w');

uid = unique(data2.uid, 'stable');

cnds = {'N2_C2','N4_C2r', 'N4_C2nr', 'N6_C2r', 'N6_C2nr', ... 
        'N4_C4','N6_C4r','N6_C4nr',...
        'N6_C6'};

breaks = [5,8];
colors = [0, 239, 91; 239, 221, 0; 239, 43, 0; 0, 105, 239] / 255;

idx = [2,3,3,4,4,3,4,4,4];
trans = [.5, 1, .5, 1, .5, .5, 1, .5, .5] ;
%trans = [.66,.66,.66,.66,1, .66, 1, .66, 1, 1, .66, 1, 1] ;
border = [1,0,0,0,0,1,0,0,1];
h = {};

dotalpha = .5;
RTbins = 20;
step = .5;
offsets = -0.066:.033:0.066;
hold all;
c = 1;
for ii = 1:length(cnds)
    precision = mean(v.mdata2{:, strcat(cnds{ii},'_','mPrecision')});
    se = std(v.mdata2{:, strcat(cnds{ii},'_','mPrecision')}) ./ sqrt(size(v.mdata1,1));
    if border(ii) == 1
        h{ii} = bar(c, precision, .33, 'FaceColor', colors(idx(ii),:), 'EdgeColor', 'k', 'FaceAlpha', 1,'LineWidth',2,'EdgeAlpha',.8);
    else
        h{ii} = bar(c, precision, .33, 'FaceColor', colors(idx(ii),:), 'FaceAlpha', trans(ii),'LineWidth',2,'EdgeAlpha', 0);
    end
    errorbar(c, precision, se, 'k', 'LineWidth', 1.5); 
    c = c + step;
    if ismember(ii,breaks)
        c = c + step;
    end
end

markers = {'x','s','^','+','d'};

for p = 1:length(uid)
    c = 1;
    for ii = 1:length(cnds)
        precision = v.mdata2{p, strcat(cnds{ii},'_','mPrecision')};
        x = c + offsets(p);
        scatter(x,precision,90,[.4,.4,.4],'linewidth',3,'MarkerEdgeAlpha',.75,'Marker',markers{p});
        c = c + step;
        if ismember(ii,breaks)
            c = c + step;
        end
    end
end

%ylim([0, 2100]);
xlim([step, c])
%yticks(0:500:2000);
set(gca, 'linewidth', 1,'fontweight','bold','fontsize',14, 'box','off','TickLabelInterpreter','LaTeX');

xticks([1:step:6*step, step*8:step:10*step, 12*step]);

xticklabels({'2', '4$_R$', '4$_{NR}$', '6$_{R}$','6$_{NR}$', ...
             '4', '6$_R$', '6$_{NR}$', ...
             '6' });

ax = gca;
ax.Position = ax.Position + [-0.05, 0.04, 0.09, 0];
ax.XRuler.TickLength = [0 0];

text(step * 4, -4, '\bf 2 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 14, 'Interpreter', 'LaTeX');

text(step * 9, -4, '\bf 4 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 14, 'Interpreter', 'LaTeX');

text(step * 12, -4, '\bf 6 Colors', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 14, 'Interpreter', 'LaTeX');

xlabel('\bf Number of Items by Number of Item Colors', 'Interpreter', 'LaTeX', 'Position', [7*step, -7]);
ylabel('\bf Precision in Abs(Degrees Error)','Interpreter','LaTeX');

h{1} = bar(nan, nan, .33, 'FaceColor', colors(idx(1),:), 'EdgeColor', 'none', 'FaceAlpha', 1);

lgd = legend([h{1},h{2},h{4}], {'\bf 2 Items','\bf 4 Items', '\bf 6 Items'}, ...
             'Location', 'northwest', 'Interpreter', 'LaTeX', 'box','off'); 

set(lgd, 'ItemTokenSize', [18, 20]);

title('\bf Experiment 2 Mean Abs. Precision','fontsize', 16, 'Interpreter','LaTeX','Position', [7*step, 58]);

SaveFig(gcf, fullfile('Figures', 'Exp2 Mean Abs Precision'), true, 150, [0 0 35 20] );

% %% Amplitude and Kappa Models 30/09/24
% clearvars -except data1 data2 v
% fprintf('Models Starting: %s\n', datetime);
% 
% % Modifier                                    Amps Kappas N-Params  #
% % Free Models                                  9A    9k    18       1
% %                                              9A    1k    10       2
% %                                              1A    9k    10       3
% % Beta on Color N              
% % Complementary Betas      Single on K (nr)    1A    1K^    3       4
% %                          Single on K (ss)    1A    1K*    3       5
% %                          Single on A (nr)    1A^   1K     3       6
% %                          Single on A (ss)    1A*   1K     3       7                 
% % Independent Betas    
% %                          Two on K (nr)       1A    1K^^   4       8
% %                          Two on K (ss)       1A    1K^^*  4       9
% %                          Two on A (nr)       1A^^  1K     4       10
% %                          Two on A (ss)       1A^^* 1K     4       11
% %                          Three on K          1A    1K^^^  5       12
% %                          Three on A          1A^^^ 1K     5       13
% % Beta on Item N              
% % Complementary Betas      Single on K (nr)    1A    1K^    3       14
% %                          Single on K (ss)    1A    1K*    3       15
% %                          Single on A (nr)    1A^   1K     3       16
% %                          Single on A (ss)    1A*   1K     3       17             
% % Independent Betas    
% %                          Two on K (nr)       1A    1K^^   4       18
% %                          Two on K (ss)       1A    1K^^*  4       19
% %                          Two on A (nr)       1A^^  1K     4       20
% %                          Two on A (ss)       1A^^* 1K     4       21
% %                          Three on K          1A    1K^^^  5       22
% %                          Three on A          1A^^^ 1K     5       23
% % Sample Size on Color     On A                1A*   1K     2       24
% %                          On K                1A    1K*    2       25
% % Sample Size on Item      On A                1A*   1K     2       26
% %                          On K                1A    1K*    2       27
% 
% initial_Amp = repmat(2, 1, 9);
% initial_Kappa = repmat(3, 1, 9);
% inital_Alpha = [.5, .5, .5];
% initial_params = [initial_Amp, initial_Kappa, inital_Alpha];
% 
% amplitudeFocus = [NaN, 1, 0, repmat( [repmat([0,0,1,1],1,2), 0, 1], 1, 2), 1, 0, 1, 0];
% complement     = [zeros(1,3), ones(1,4), zeros(1,6), ones(1,4), zeros(1,6), 1, 1, 1, 1];
% betas          = [0,0,0, 1,1,1,1, 2,2,2,2, 3,3, 1,1,1,1, 2,2,2,2, 3,3, 0,0,0,0];
% NRstandard     = [NaN,NaN,NaN, 1,0,1,0, 1,0,1,0, 0,0, 1,0,1,0, 1,0,1,0, 0,0, 0,0,0,0];
% ItemOrColor    = [0,0,0, ones(1,10), ones(1,10) * 2, 1, 1, 2, 2];
% 
% % If complement == 0 & betas == 0 & ampFocus == NaN: Fully Free Model
% % If complement == 0 & betas == 0 & ampFocus == 1 | 0: Focused Free Model
% 
% % If complement == 1 & betas > 0: Power Law Complement (n ^ -beta vs n ^ beta)
% % If complement == 0 & betas > 0: Independent Power Law betas (2 | 3 betas)
% % If complement == 1 & betas == 0: +-Sample Size Beta (0.5).
% % If NRstandard == 1: Standard conditions share beta with non-redundant conditions.
% 
% FreeFix = { [ones(1, 18), zeros(1, 3)], ...
%             [ones(1, 10), zeros(1, 11)], ...
%             [1, zeros(1, 8), ones(1,9), zeros(1, 3)], ...
%             ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 1], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 1], ...
%             ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 0, 0], ...
%             ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 1], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 1, 1, 1], ...
%             ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 0, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 0, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 0, 0, 0], ...
%             [1, zeros(1, 8), 1, zeros(1, 8), 0, 0, 0]};
% 
% 
% uid = unique(data2.uid, 'stable');
% ModelResults = table(repmat(uid, size(FreeFix,2), 1), 'VariableNames', {'ID'});
% c = 1;
% for ModelRun = 1:size(FreeFix,2)
%     FreeParams = FreeFix{ModelRun};
%     modifiers  = [amplitudeFocus(ModelRun), ...
%                   complement(ModelRun) ...
%                   betas(ModelRun) ... 
%                   NRstandard(ModelRun), ... 
%                   ItemOrColor(ModelRun)];
%     for p = 1:length(uid)
%         Data = data2( strcmp( data2.uid, uid{p} ), :);
% 
%         [Pred] = fminsearch(@(Pvar) MaxGumbelModels2( ... 
%                                                 Pvar, ...
%                                                 initial_params(FreeParams == 0),...
%                                                 FreeParams, ...
%                                                 Data, ...
%                                                 modifiers), ...
%                     initial_params(FreeParams == 1), v.Model.options);
% 
%         [ll, aic, bic, estPred, ModelID, rawAIC, rawBIC] = MaxGumbelModels2(Pred, initial_params(FreeParams == 0), FreeParams, Data, modifiers);
% 
%         ModelResults.Model(c) = {ModelID};
%         ModelResults.LogLike(c) = ll;
%         ModelResults.qAIC(c) = aic;
%         ModelResults.qBIC(c) = bic;
%         ModelResults.AIC(c) = rawAIC;
%         ModelResults.BIC(c) = rawBIC;
% 
%         TmpParams = FreeParams;
%         TmpParams(FreeParams == 0) = nan;
%         TmpParams(FreeParams == 1) = Pred;
%         ModelResults.FreeParams(c) = {TmpParams};
%         ModelResults.EstValues(c) = {estPred};
%         ModelResults.StartingParams(c) = {initial_params};
%         ModelResults.ModelRun(c) = ModelRun;
% 
%         c = c + 1;
%     end
%     fprintf('Model %i of %i Complete.\n', ModelRun, size(FreeFix,2));
% end
% v.ModelResults = ModelResults;
% fprintf('Models Finished: %s\n', datetime);
% save('ModelOutput.mat', 'data1', 'data2', 'v');

%% Plot Model Results as Distributions
clear; close; clc; 
load('ModelOutput.mat');

uid = unique(data2.uid, 'stable');
model = 'Mod.A, Two Independent Betas, NR on Standard by ColorN';
basemodel = 'Free A';

% model = 'SS on Amplitude by ColorN';
% basemodel = 'Free A';

% model = 'Mod.K, Two Independent Betas, NR on Standard by ColorN';
% basemodel = 'Free K';

t = {'\bf 2$|$2', '\bf 4$|$2$_r$', '\bf 4$|$2$_{nr}$', ... 
    '\bf 4$|$4', '\bf 6$|$2$_r$', '\bf 6$|$2$_{nr}$', ...
    '\bf 6$|$4$_r$', '\bf 6$|$4$_{nr}$', '\bf 6$|$6'};
h = {};
histcol = ones(9, 3);
histcol([1,2,3,5,6],:) = repmat([.0, .1, .2], 5, 1);
histcol([4,7,8],:) = repmat([.3, .4, .5], 3, 1);
histcol(9,:) = [.6, .7, .8];

for p = 1:length(uid)
    set(figure(p), 'Position', get(0, 'Screensize'), 'color','w');
    for cnd = 1:9
        subplot_tight(3,3,cnd, [.08, .07]);
        hold all;
        
        emperical = deg2rad(data2.response_error(strcmp(data2.uid, uid{p}) & data2.Cnd == cnd));
        
        predicted = v.ModelResults.EstValues{ strcmp(v.ModelResults.ID, uid{p}) & strcmp(v.ModelResults.Model, model) }{cnd};
        predicted(2,:) = predicted(2,:) / trapz(predicted(1,:), predicted(2,:));

        basepred = v.ModelResults.EstValues{ strcmp(v.ModelResults.ID, uid{p}) & strcmp(v.ModelResults.Model, basemodel) }{cnd};
        basepred(2,:) = basepred(2,:) / trapz(basepred(1,:), basepred(2,:));

        h{cnd} = histogram(emperical, 'Normalization', 'pdf', 'EdgeColor', 'none', 'FaceColor', histcol(cnd,:), 'BinWidth', basepred(3) - basepred(1) ,'FaceAlpha', 1);
        h{2} = plot(basepred(1,:), basepred(2,:), 'Color', [0, 0, 1, .66], 'LineStyle', '-', 'LineWidth', 3);
        h{3} = plot(predicted(1,:), predicted(2,:), 'Color', [1, 0, 0, .66], 'LineStyle', '-', 'LineWidth', 3);

        xlim([-pi, pi]);
        ylim([0, 2.5]);
        set(gca, 'linewidth', 1,'fontweight','bold','fontsize',14, 'box','off','TickLabelInterpreter','LaTeX');

        xticks(-pi:pi/2:pi);
        yticks(0:1:2);
        xticklabels({'-$\pi$', '-$\frac{\pi}{2}$', '0', '$\frac{\pi}{2}$', '$\pi$'});

        if cnd == 8
            xlabel('\bf Error in Radians', 'Interpreter', 'LaTeX', 'fontsize', 12);
        end
        if cnd == 4
            ylabel('\bf Probability Density','Interpreter','LaTeX','fontsize', 12);
        end

        title(t{cnd},'fontsize', 12, 'Interpreter','LaTeX');

        if cnd == 1
            lgd = legend([h{1},h{2},h{3}], {'\bf Data','\bf Free Fit','\bf Model Fit'}, ...
             'Location', 'northwest', 'Interpreter', 'LaTeX', 'box','off', 'FontSize',10); 
            set(lgd, 'ItemTokenSize', [18, 20]);    
        end

    end
    SuperTitle(['\bf P0', num2str(p)],14, .95);
    SaveFig(gcf, fullfile('Figures', ['EmpericalFit_P0', num2str(p),'_', strrep(model, '.', '')]), true, 150, [0 0 35 20] );
end


%% Circular Precision Plots
clear; close; clc; 
load('ModelOutput.mat');
uid = unique(data2.uid, 'stable');

model = 'Mod.A, Two Independent Betas, NR on Standard by ColorN';

colors = [239, 221, 0; 239, 43, 0; 0, 105, 239] / 255;
%2 42 42 4 62 62 64 64 6  
ci = [1,2,2,2,3,3,3,3,3];
trans = [1, .5, .5, 1, .5, .5, .5, .5, 1];

breaks = [6,8];
cnds = [1,2,3,5,6, 4,7,8, 9];
step = 0.75;
os = 0.2;
set(figure(1), 'Position', get(0, 'Screensize'), 'color','w');
for p = 1:length(uid)
    c = 1;
    for cnd = cnds
        subplot_tight(2,3,p, [.08, .07]);
        hold all;
        % Calculate emperical variance and precision (circ std).
        d = data2(strcmp(data2.uid, uid{p}) & data2.Cnd == cnd,:);
        [e_precision, e_variance, e_SEr, e_SEs] = circular_std(deg2rad(d.response_error));

        % Calculate predicted variance and precision.
        predicted = v.ModelResults.EstValues{ strcmp(v.ModelResults.ID, uid{p}) & strcmp(v.ModelResults.Model, model) }{cnd};
        predicted(2,:) = predicted(2,:) / trapz(predicted(1,:), predicted(2,:));
        predicted(2,:) = predicted(2,:) / sum(predicted(2,:));
        
        cosSum = sum( predicted(2,:) .* cos(predicted(1,:)));
        sinSum = sum( predicted(2,:) .* sin(predicted(1,:)));
        
        rvectleng = sqrt(cosSum ^ 2 + sinSum ^ 2); % Also known as resultant vector length
        p_precision = sqrt(-2 * log(rvectleng));
        p_variance = 1 - rvectleng;
        p_SEr = sqrt(1 - rvectleng ^ 2) / sqrt(size(d,1));
        p_SEs = (1 / (rvectleng * sqrt(-2 * log(rvectleng)))) * p_SEr;

        h{cnd} = bar(c-os, e_precision, .33, 'FaceColor', colors(ci(cnd),:), 'FaceAlpha', trans(cnd),'LineWidth',2,'EdgeAlpha', 0, 'BarWidth',.25);
        h{10} = bar(c+os, p_precision, .33, 'FaceColor', [.66, .66, .66], 'FaceAlpha', trans(cnd),'LineWidth',2,'EdgeAlpha', 0);

        errorbar(c-os, e_precision, e_SEs, 'k', 'LineWidth', 1.5); 
        errorbar(c+os, p_precision, p_SEs, 'color', [.33, .33, .33], 'LineWidth', 1.5); 
        
        c = c + step;
        if ismember(cnd, breaks)
            c = c + step;
        end


    end
    set(gca, 'linewidth', 1,'fontweight','bold','fontsize',10, 'box','off','TickLabelInterpreter','LaTeX');
    xlim([1-step, c]);
    xticks([1:step:1+step*4, 1+step*6:step:1+step*8, 1+step*10])
    xticklabels({'2', '4$_R$', '4$_{NR}$', '6$_{R}$','6$_{NR}$', ...
                '4', '6$_R$', '6$_{NR}$', ...
                '6' });
    ylim([0, 1.3]);
    yticks([0, .6, 1.2]);
    text(1+step * 2, -.12, '\bf2C', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 9, 'Interpreter', 'LaTeX');
    text(1+step * 7, -.12, '\bf4C', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 9, 'Interpreter', 'LaTeX');
    text(1+step * 10, -.12, '\bf6C', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 9, 'Interpreter', 'LaTeX');

    title(['\bf P0', num2str(p)],'fontsize', 14, 'Interpreter','LaTeX','Position', [1+5*step, 1.2]);


    if p == 5
        lgd = legend([h{1}, h{4}, h{9}, h{8},h{10}], {'2 Item Data','4 Item Data','6 Item Data','Redundant Conditions','Model Predictions'}, ...
             'Location', 'northeast', 'Interpreter', 'LaTeX', 'box','off', ...
             'FontSize', 12, 'EdgeColor', 'none', 'NumColumns', 1); 
        lgd.ItemTokenSize = [8, 10];
        
        set(lgd, 'Units', 'normalized');  % Use normalized units
        lgd.Position = lgd.Position + [0.2 0.00 0.0 0.0];
    end
    
    if ismember(p, [1,4])
        ylabel('\bf Precision (Circular SD)','Interpreter','LaTeX');
    end
    
end
SuperTitle('\bf Emperical vs Model Fit Precision',14, .95);
SaveFig(gcf, fullfile('Figures', ['ModelvsEmpericalPrecision_', strrep(model, '.', '')]), true, 150, [0 0 35 20] );

%% Scatter Precision for Model Fit Comparison

clear; close; clc; 
load('ModelOutput.mat');
uid = unique(data2.uid, 'stable');

model = 'Mod.A, Two Independent Betas, NR on Standard by ColorN';
%colors = [239, 221, 0; 239, 43, 0; 0, 105, 239] / 255; %By Item
colors = [255, 128, 0; 0, 128, 255; 255, 0, 127] / 255;  %By Color
%2 42 42 4 62 62 64 64 6  
ci = [1,1,1,2,1,1,2,2,3]; % By Item
os = [0,-.018,0.018, 0, -0.036, 0.036, -.018, .018, 0];
os2 = [-0.005, 0.005];

trans = [.8, .6, .6, .8, .6, .6, .6, .6, .8];
ix = [0,1,0,1.08,0,1.2];
sym = {'o','d','s','o','d','s','d','s','o'};

breaks = [6,8];
cnds = [1,2,3,5,6, 4,7,8, 9];
set(figure(1), 'Position', get(0, 'Screensize'), 'color','w');
for p = 1:length(uid)
    for cnd = cnds
        subplot_tight(2,3,p, [.08, .07]);
        hold all;
        % Calculate emperical variance and precision (circ std).
        d = data2(strcmp(data2.uid, uid{p}) & data2.Cnd == cnd,:);
        [e_precision, e_variance, e_seR, e_SEs] = circular_std(deg2rad(d.response_error));

        % Calculate predicted variance and precision.
        predicted = v.ModelResults.EstValues{ strcmp(v.ModelResults.ID, uid{p}) & strcmp(v.ModelResults.Model, model) }{cnd};
        predicted(2,:) = predicted(2,:) / trapz(predicted(1,:), predicted(2,:));
        predicted(2,:) = predicted(2,:) / sum(predicted(2,:));
        
        cosSum = sum( predicted(2,:) .* cos(predicted(1,:)));
        sinSum = sum( predicted(2,:) .* sin(predicted(1,:)));
        
        rvectleng = sqrt(cosSum ^ 2 + sinSum ^ 2);
        p_precision = sqrt(-2 * log(rvectleng));
        p_variance = 1 - rvectleng;
        p_SEr = sqrt(1 - rvectleng ^ 2) / sqrt(size(d,1));
        p_SEs = (1 / (rvectleng * sqrt(-2 * log(rvectleng)))) * p_SEr;

        n = d.num_itemsi(1);

        errorbar(ix(n) + os(cnd) + os2(1), e_precision, e_SEs, 'k', 'LineWidth', 1.5); 
        errorbar(ix(n) + os(cnd) + os2(2), p_precision, p_SEs, 'color', [.5, .5, .5], 'LineWidth', 1.5); 
        
        h{cnd} = scatter(ix(n) + os(cnd) + os2(1), e_precision, 120, 'MarkerFaceColor', colors(ci(cnd),:),'Marker',sym{cnd}, 'MarkerFaceAlpha',trans(cnd),'MarkerEdgeAlpha',0);
        h{10}  = scatter(ix(n) + os(cnd) + os2(2), p_precision, 100, 'MarkerEdgeColor', colors(ci(cnd),:), 'Marker',sym{cnd}, 'MarkerFaceAlpha',0, 'LineWidth',2,'MarkerEdgeAlpha',.75);   

    end
    title(['\bf P0', num2str(p)],'fontsize', 14, 'Interpreter','LaTeX');
    set(gca, 'linewidth', 1,'fontweight','bold','fontsize',12, 'box','off','TickLabelInterpreter','LaTeX');
    xlim([.98, 1.25]);
    xticks([ix(2), ix(4), ix(6)])
    xticklabels({'2','4','6'});
    ylim([0, 1.3]);
    yticks([0, .65, 1.3]);

    if ismember(p, [1,4])
        ylabel('\bf Precision (Circular SD)','Interpreter','LaTeX');
    end

    if ismember(p, [3,4,5])
        xlabel('\bf Number of Items','Interpreter','LaTeX');
    end

    if p == 5
        lgd = legend([h{1}, h{4}, h{9}, h{2}, h{3}, h{10}], {'Two Colors','Four Colors','Six Colors','Redundant Cued','Non-Redundant Cued','Model Predictions'}, ...
             'Location', 'northeast', 'Interpreter', 'LaTeX', 'box','off', ...
             'FontSize', 12, 'EdgeColor', 'none', 'NumColumns', 1); 
        
        set(lgd, 'Units', 'normalized');  % Use normalized units
        lgd.Position = lgd.Position + [0.2 -0.05 0.0 0.0];
    end
    
end
SuperTitle('\bf Emperical vs Model Fit Precision',14, .95);
SaveFig(gcf, fullfile('Figures', ['Scatter_ModelvsEmpericalPrecision_', strrep(model, '.', '')]), true, 150, [0 0 35 20] );



