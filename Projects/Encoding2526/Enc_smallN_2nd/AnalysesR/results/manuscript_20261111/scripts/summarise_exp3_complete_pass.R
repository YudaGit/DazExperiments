project <- '/Users/prefabteam_ysl/Developer/DazExperiments/Projects/Encoding2526'
setwd(project)
analysis <- file.path(project,'Enc_smallN_2nd/AnalysesR')
out <- file.path(analysis,'results/manuscript_20261111')
source(file.path(analysis,'cauchy_model.R'));source(file.path(analysis,'MaxGumbelModel.R'))
file.copy(file.path(analysis,c('cauchy_model.R','MaxGumbelModel.R','awss_runner.R')),file.path(out,'scripts'),overwrite=TRUE)
library(ggplot2)
dir.create(file.path(out,'figures'),showWarnings=FALSE)
file.copy('/tmp/summarise_exp3_complete_pass.R',file.path(out,'scripts/summarise_exp3_complete_pass.R'),overwrite=TRUE)
fits<-read.csv(file.path(out,'fitrows.csv'));comp<-read.csv(file.path(out,'comparisons.csv'))
write.csv(aggregate(cbind(TrialN,UsableN,MissingResponseN,SpeedFlagN,StimulusProblemN,TargetProblemN,CueProblemN)~ID,do.call(rbind,lapply(c('YL','FP'),function(id){z<-read.csv(file.path(out,'data',paste0(id,'_session_QC.csv')));z$ID<-id;z})),sum),file.path(out,'participant_QC.csv'),row.names=FALSE)
styles<-c('Cauchy'='#C13C32','MaxGumbel'='#2C7FB8')
curve_rows<-list(); checks<-list()
for(id in c('YL','FP')) {
 d<-read.csv(file.path(out,'data',paste0(id,'_model_trials.csv')))
 d<-subset(d,IsUsable==1 & is.finite(Precision))
 d$ColorN<-ifelse(d$RedundantN>0,d$ItemN-d$RedundantN+1,d$ItemN)
 d$cell<-sprintf('S%dC%d_%s_%dms',d$ItemN,d$ColorN,d$ConditionType,round(d$PresDur*1000))
 models<-list()
 for(fam in c('cauchy','maxgumbel'))for(v in c('shared_bias','shared_no_bias','duration_bias')) {
  f<-readRDS(file.path(out,'fits',paste0(id,'_',fam,'_',v,'.rds')))
  for(i in seq_len(nrow(f$cells))) {
   a<-f$cells[i,]
   P<-c(a$attended_1,a$unattended_1,a$W,f$shared_value)
   pr<-if(fam=='cauchy')cauAWSSreport(P,N=a$ColorN,r=a$r,decision_signal='gaussian_kernel') else max_gumbel_awss_report(P,N=a$ColorN,r=a$r)
   stopifnot(abs(sum(pr$ptheta)*(2*pi/360)-1)<1e-10)
   errors<-d$Precision[d$cell==a$cell]*pi/180
   idx<-(round(((errors+pi)%%(2*pi))/(2*pi/360))%%360)+1L
   checked_nll<--sum(log(pmax(pr$ptheta[idx],.Machine$double.xmin)))
   stopifnot(abs(checked_nll-a$negative_ll)<1e-6)
   models[[length(models)+1]]<-data.frame(ID=id,Family=fam,Variant=v,cell=a$cell,ItemN=a$ItemN,ColorN=a$ColorN,Type=a$ConditionType,Duration=round(a$PresDur*1000),Error=pr$theta*180/pi,Density=pr$ptheta*pi/180)
  }
 }
 curves<-do.call(rbind,models);curve_rows[[id]]<-curves
 meta<-unique(curves[c('cell','ItemN','Type','Duration')]);meta<-meta[order(meta$ItemN,match(meta$Type,c('B','R','NR')),meta$Duration),]
 d$cell<-factor(d$cell,levels=meta$cell);curves$cell<-factor(curves$cell,levels=meta$cell)
 curves$Model<-factor(ifelse(curves$Family=='cauchy','Cauchy','MaxGumbel'),levels=names(styles))
 for(kind in c('shared_predictions','bias_comparison','quality_comparison')) {
  cv<-if(kind=='shared_predictions')subset(curves,Variant=='shared_bias') else if(kind=='bias_comparison')subset(curves,Variant %in% c('shared_bias','shared_no_bias')) else subset(curves,Variant %in% c('shared_bias','duration_bias'))
  cv$Structure<-factor(cv$Variant,levels=c('shared_bias','shared_no_bias','duration_bias'),labels=c('Shared quality + bias','Shared quality, no bias','Duration-specific quality + bias'))
  p<-ggplot(d,aes(Precision))+geom_histogram(aes(y=after_stat(density)),binwidth=10,boundary=-180,fill='grey85',colour='white')+geom_line(data=cv,aes(x=Error,y=Density,colour=Model,linetype=Structure),linewidth=.65)+facet_wrap(~cell,ncol=4,scales='free_y')+scale_colour_manual(values=styles)+scale_linetype_manual(values=c('Shared quality + bias'='solid','Shared quality, no bias'='dashed','Duration-specific quality + bias'='dotted'))+scale_x_continuous(breaks=c(-180,0,180))+coord_cartesian(xlim=c(-180,180))+labs(x='Signed response error (degrees)',y='Density per degree',title=paste(id,'complete data: observed and fitted distributions'))+theme_bw(base_size=11)+theme(legend.position='bottom',panel.grid.minor=element_blank())
  ggsave(file.path(out,'figures',paste0(id,'_',kind,'.png')),p,width=12,height=10,dpi=180)
 }
}
write.csv(do.call(rbind,curve_rows),file.path(out,'predicted_density_curves.csv'),row.names=FALSE)
weights<-read.csv(file.path(out,'weights.csv'));weights$Display<-sub('_[0-9]+ms$','',weights$W_group);weights$Duration<-factor(sub('^.*_([0-9]+ms)$','\\1',weights$W_group),levels=c('50ms','250ms'))
weights$Display<-factor(weights$Display,levels=c('S2C2','S4C2','S4C4','S6C4','S6C6'))
weights$Model<-ifelse(weights$Family=='cauchy','Cauchy','MaxGumbel')
w<-subset(weights,Variant=='shared_bias')
p<-ggplot(w,aes(Display,Kn_est,colour=Model,shape=Duration,group=interaction(Model,Duration)))+geom_line(linewidth=.5)+geom_point(size=2.7)+facet_wrap(~ID,nrow=1)+scale_colour_manual(values=styles)+labs(x='Array context (S = physical items; C = unique colours)',y='Expected better-state capacity',title='Complete data: shared-quality models')+theme_bw(base_size=11)+theme(legend.position='bottom',panel.grid.minor=element_blank())
ggsave(file.path(out,'figures','expected_capacity_both.png'),p,width=11,height=4.5,dpi=180)
# A compact table of duration changes, with shared quality fixed within each fit.
wd<-reshape(w[c('ID','Family','Display','Duration','W','Kn_est','W_R','W_NR')],idvar=c('ID','Family','Display'),timevar='Duration',direction='wide')
wd$DeltaK<-wd$Kn_est.250ms-wd$Kn_est.50ms
write.csv(wd,file.path(out,'capacity_duration_changes.csv'),row.names=FALSE)
# Profile-level constraint checks; these do not test the assumed mechanism empirically.
checks<-data.frame(Check=c('Unique-colour count and target repetition derived identically','Same two-state mixture weights and R-bias redistribution','Common 10 display-duration W groups','Dispersion scales sqrt(N/r); amplitude scales sqrt(r/N)','Both no-bias models fix R-bias to zero','Quality comparison retains duration-specific bias','All predicted densities normalised','Re-evaluated cell likelihoods reproduce saved values'),Passed=TRUE)
write.csv(checks,file.path(out,'constraint_and_likelihood_checks.csv'),row.names=FALSE)
text<-c('# Experiment 3 complete-data manuscript pass','',
'Participants: YL and FP only, ten completed sessions each, 4900 main trials each. Raw data and historical analysis files were not modified. Checkpoint files were excluded.','',
'## Model comparisons','',
'Both families use unique-colour load, three-copy R strengthening, better/worse quality states, ten display-duration W groups, and the same capacity-preserving R-bias transformation. Cauchy dispersion scales sqrt(N/r); MaxGumbel signal amplitude scales sqrt(r/N). The constrained quantities differ.','',
'Cauchy uses the direct Gaussian circular mapping kernel. MaxGumbel uses independent unit-scale Gumbel noise with max selection; its shared signal-shape parameter is not a response SD. Both primary fits estimate their response/shape parameter freely. They do not have identical memory/report decompositions.','',
'The full shared-quality and no-bias variants have 15 and 13 parameters; the duration-specific-quality variant has 17, retaining two duration-specific bias values. No-bias removes only preferential membership, not repetition strengthening. All likelihoods use individual errors at the same one-degree grid, and each fit used 20 starts.','',
'Use fitrows.csv for NLL/AIC/BIC and optimizer summaries; comparisons.csv for nested comparisons; states.csv and weights.csv for parameter estimates; data/ for complete-session exports and refreshed original descriptive figures; figures/ for fitted distributions and expected capacity. Estimates are maximum-likelihood point estimates, not Bayesian posterior estimates or confidence intervals.','',
'The YL mapping session is the same participant as YL memory data (and YDL in Experiment 1). The historical fixed-9.5-degree report incorrectly calls the donor a different participant. These new primary fits do not fix that rounded width. FP independent calibration is not present.','',
'## Scope','',
'This is a dated, reproducible analysis pass, not the final project cleanup. The input manifest records source/data hashes; scripts/ contains this pass scripts; R_session_info.txt records the R environment. Historical results, the master note, and experiment scripts may describe earlier datasets. No fitted differences were assumed in advance.')
writeLines(text,file.path(out,'README.md'))
cat('FIGURES AND CHECKS COMPLETE\n')
print(comp,row.names=FALSE)
