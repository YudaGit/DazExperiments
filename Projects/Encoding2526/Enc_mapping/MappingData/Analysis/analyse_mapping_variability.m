% Fit one von Mises to signed errors, allowing a free mean direction.
analysisDir = fileparts(mfilename('fullpath'));
t = readtable(fullfile(analysisDir,'completed_main_trials.csv'));
assert(height(t)==540 && all(t.Completed) && ~any(t.TimedOut));
assert(all(isfinite(t.SignedErrorDeg)));
assert(max(abs(mod(t.TargetHueDeg-t.ResponseHueDeg+180,360)-180-t.SignedErrorDeg))<1e-8);
seeds = unique(t.TargetHueDeg);
rng(20261105); nBoot = 5000;
bootZ = zeros(1,nBoot);
perSeed = table();
for i = 1:numel(seeds)
    e = deg2rad(t.SignedErrorDeg(t.TargetHueDeg==seeds(i)));
    assert(numel(e)==15);
    z = exp(1i*e);
    resampledZ = z(randi(numel(z),numel(z),nBoot));
    rBoot = abs(mean(resampledZ,1));
    bootZ = bootZ + sum(resampledZ,1);
    stats = fitRow(e,rBoot);
    row = [table(seeds(i),'VariableNames',{'SeedDeg'}),stats];
    perSeed = [perSeed;row];
end
overall = fitRow(deg2rad(t.SignedErrorDeg),abs(bootZ/height(t)));
writetable(overall, fullfile(analysisDir,'overall_von_mises.csv'));
writetable(perSeed, fullfile(analysisDir,'seed_von_mises.csv'));
% Verify the fitted parameter solves the MLE score equation.
assert(abs(besseli(1,overall.Kappa,1)/besseli(0,overall.Kappa,1)-overall.Rbar)<1e-10);
for i=1:height(perSeed)
    k=perSeed.Kappa(i);
    assert(abs(besseli(1,k,1)/besseli(0,k,1)-perSeed.Rbar(i))<1e-10);
end
f=figure('Visible','off','Color','w','Position',[100 100 1400 550]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; histogram(t.SignedErrorDeg,-50:2:50,'Normalization','pdf', ...
    'FaceColor',[0.25 0.48 0.68],'EdgeColor','none');hold on;
x=linspace(-50,50,1000);k=overall.Kappa;mu=deg2rad(overall.BiasDeg);
pdf=exp(k*(cos(deg2rad(x)-mu)-1))/(2*pi*besseli(0,k,1))*pi/180;
plot(x,pdf,'Color',[0.85 0.3 0.18],'LineWidth',2);
xlabel('Signed error: nominal target - response (degrees)');ylabel('Density per degree');
title(sprintf('Overall: kappa = %.2f, circular SD = %.2f deg',k,overall.CircularSDDeg));
legend('540 responses','Von Mises fit','Location','northwest');box off;
nexttile;
errorbar(perSeed.SeedDeg,perSeed.CircularSDDeg, ...
    max(0,perSeed.CircularSDDeg-perSeed.CircularSDLower95), ...
    max(0,perSeed.CircularSDUpper95-perSeed.CircularSDDeg),'o-', ...
    'Color',[0.15 0.4 0.6],'MarkerFaceColor',[0.15 0.4 0.6], ...
    'MarkerSize',4,'LineWidth',1,'CapSize',3);
xlabel('Nominal seed colour (degrees)');ylabel('Circular SD (degrees)');
title('Per-seed variability: 15 trials each, 95% bootstrap intervals');
xlim([-5 355]);xticks(0:30:350);grid on;box off;
exportgraphics(f,fullfile(analysisDir,'response_variability.png'),'Resolution',160);close(f);
disp(overall);disp(perSeed(:,{'SeedDeg','N','BiasDeg','Kappa','CircularSDDeg'}));

function stats=fitRow(e,rBoot)
z=mean(exp(1i*e));r=abs(z);k=estimateKappa(r);
rCI=prctile(rBoot,[2.5 97.5]);
kCI=[estimateKappa(rCI(1)),estimateKappa(rCI(2))];
csd=rad2deg(sqrt(-2*log(r)));
csdCI=rad2deg(sqrt(-2*log(rCI([2 1]))));
width=rad2deg(1/sqrt(k));
widthCI=rad2deg(1./sqrt(kCI([2 1])));
stats=table(numel(e),rad2deg(angle(z)),r,k,1/k,width,csd, ...
    kCI(1),kCI(2),widthCI(1),widthCI(2),csdCI(1),csdCI(2), ...
    'VariableNames',{'N','BiasDeg','Rbar','Kappa','Dispersion1OverKappa', ...
    'VMWidthDeg','CircularSDDeg','KappaLower95','KappaUpper95', ...
    'VMWidthLower95','VMWidthUpper95','CircularSDLower95','CircularSDUpper95'});
end
function k=estimateKappa(r)
if r<=0,k=0;return;end
if r>=1,k=Inf;return;end
upper=max(10,2/(1-r));
k=fzero(@(x)besseli(1,x,1)/besseli(0,x,1)-r,[0 upper]);
end
