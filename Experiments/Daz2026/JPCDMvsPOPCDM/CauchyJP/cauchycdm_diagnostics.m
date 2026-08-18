function diagnosticRows = cauchycdm_diagnostics( ...
        uid, dp, condFit, condLevels, tmax, outputDir)
%CAUCHYCDM_DIAGNOSTICS Angle/RT densities and proportion diagnostics.

    if ~exist(outputDir,'dir'), mkdir(outputDir); end
    nCond=numel(condLevels);
    angleEdges=-180:5:180;
    rtEdges=0.3:0.025:3;
    rtPropEdges=[0.3,1.0,1.3,1.6,2.0,3.0];
    angleLabels=["Central <=15", "Shoulder 15-45", "Tail >45"];
    rtLabels=["0.3-1.0", "1.0-1.3", "1.3-1.6", "1.6-2.0", "2.0-3.0"];
    diagnosticRows=table();

    fAngle=figure('Visible','off','Color','w','Position',[40 40 1300 900]);
    tiledlayout(3,3,'TileSpacing','compact');
    fRT=figure('Visible','off','Color','w','Position',[50 50 1300 900]);
    tiledlayout(3,3,'TileSpacing','compact');
    fAngleProp=figure('Visible','off','Color','w','Position',[60 60 1300 900]);
    tiledlayout(3,3,'TileSpacing','compact');
    fRTProp=figure('Visible','off','Color','w','Position',[70 70 1300 900]);
    tiledlayout(3,3,'TileSpacing','compact');

    for c=1:nCond
        dc=dp(dp.condIdx==c,:);
        P7=[condFit.Vnorm(c),condFit.Eta1(c),condFit.Eta2(c), ...
            condFit.A(c),condFit.Kappa(c),condFit.Ter(c),condFit.St(c)];
        [T,Gt,Theta]=cauchycdm2(P7,tmax);
        Gt=max(Gt,0);
        dtheta=Theta(2)-Theta(1);
        dt=T(2)-T(1);
        keep=T>=0.3&T<=3;
        Gt=Gt/(sum(Gt(:,keep),'all')*dtheta*dt);
        angleDensity=sum(Gt(:,keep),2)*dt;
        rtDensity=sum(Gt(:,keep),1)*dtheta;

        figure(fAngle); nexttile;
        histogram(dc.rAngle*180/pi,'Normalization','pdf','BinEdges',angleEdges, ...
            'FaceColor',[.2 .45 .9],'FaceAlpha',.25,'EdgeColor','none'); hold on;
        plot([Theta,pi]*180/pi,[angleDensity;angleDensity(1)]*pi/180, ...
            'r-','LineWidth',1.8); hold off; xlim([-180 180]);
        title(condLevels(c),'Interpreter','none'); xlabel('Error (deg)'); ylabel('Density');

        figure(fRT); nexttile;
        histogram(dc.rt,'Normalization','pdf','BinEdges',rtEdges, ...
            'FaceColor',[.2 .45 .9],'FaceAlpha',.25,'EdgeColor','none'); hold on;
        plot(T(keep),rtDensity(keep),'r-','LineWidth',1.8); hold off; xlim([.3 3]);
        title(condLevels(c),'Interpreter','none'); xlabel('RT (s)'); ylabel('Density');

        absObs=abs(dc.rAngle)*180/pi;
        absTheta=abs(Theta)*180/pi;
        obsAngle=[mean(absObs<=15),mean(absObs>15&absObs<=45),mean(absObs>45)];
        modelAngleP=angleDensity*dtheta;
        modAngle=[sum(modelAngleP(absTheta<=15)), ...
            sum(modelAngleP(absTheta>15&absTheta<=45)),sum(modelAngleP(absTheta>45))];
        figure(fAngleProp); nexttile;
        bar([obsAngle;modAngle].'); ylim([0 1]); title(condLevels(c),'Interpreter','none');
        xticks(1:3); xticklabels(angleLabels); xtickangle(20);
        if c==1, legend({'Observed','Model'},'Location','best'); end
        ylabel('Proportion');

        obsRT=histcounts(dc.rt,rtPropEdges,'Normalization','probability');
        modRT=zeros(1,numel(rtPropEdges)-1);
        for b=1:numel(modRT)
            if b<numel(modRT), inBin=T>=rtPropEdges(b)&T<rtPropEdges(b+1);
            else, inBin=T>=rtPropEdges(b)&T<=rtPropEdges(b+1); end
            modRT(b)=sum(rtDensity(inBin))*dt;
        end
        figure(fRTProp); nexttile;
        bar([obsRT;modRT].'); ylim([0 1]); title(condLevels(c),'Interpreter','none');
        xticks(1:numel(rtLabels)); xticklabels(rtLabels); xtickangle(25);
        if c==1, legend({'Observed','Model'},'Location','best'); end
        ylabel('Proportion');

        for b=1:3
            diagnosticRows=[diagnosticRows; table(uid,condLevels(c),"Angle", ...
                angleLabels(b),obsAngle(b),modAngle(b), ...
                'VariableNames',{'uid','Cond','Measure','Bin','Observed','Model'})]; %#ok<AGROW>
        end
        for b=1:numel(rtLabels)
            diagnosticRows=[diagnosticRows; table(uid,condLevels(c),"RT", ...
                rtLabels(b),obsRT(b),modRT(b), ...
                'VariableNames',{'uid','Cond','Measure','Bin','Observed','Model'})]; %#ok<AGROW>
        end
    end
    figure(fAngle); sgtitle(uid+" Cauchy-CDM H0 response-error densities");
    figure(fRT); sgtitle(uid+" Cauchy-CDM H0 RT densities");
    figure(fAngleProp); sgtitle(uid+" Cauchy-CDM H0 angle proportions");
    figure(fRTProp); sgtitle(uid+" Cauchy-CDM H0 RT proportions");
    exportgraphics(fAngle,fullfile(outputDir,uid+"_angle_density.png"),'Resolution',160);
    exportgraphics(fRT,fullfile(outputDir,uid+"_rt_density.png"),'Resolution',160);
    exportgraphics(fAngleProp,fullfile(outputDir,uid+"_angle_proportions.png"),'Resolution',160);
    exportgraphics(fRTProp,fullfile(outputDir,uid+"_rt_proportions.png"),'Resolution',160);
    close([fAngle,fRT,fAngleProp,fRTProp]);
    writetable(diagnosticRows,fullfile(outputDir,uid+"_proportions.csv"));
end
