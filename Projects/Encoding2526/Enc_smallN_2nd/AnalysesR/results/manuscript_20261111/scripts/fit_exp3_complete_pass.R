project <- '/Users/prefabteam_ysl/Developer/DazExperiments/Projects/Encoding2526'
setwd(project)
analysis <- file.path(project,'Enc_smallN_2nd/AnalysesR')
out <- file.path(analysis,'results/manuscript_20261111')
dir.create(file.path(out,'fits'),recursive=TRUE,showWarnings=FALSE)
dir.create(file.path(out,'scripts'),recursive=TRUE,showWarnings=FALSE)
file.copy('/tmp/fit_exp3_complete_pass.R',file.path(out,'scripts/fit_exp3_complete_pass.R'),overwrite=TRUE)
file.copy('/tmp/refresh_exp3_complete_sessions.m',file.path(out,'scripts/refresh_exp3_complete_sessions.m'),overwrite=TRUE)
source(file.path(analysis,'cauchy_model.R'))
source(file.path(analysis,'MaxGumbelModel.R'))
source(file.path(analysis,'awss_runner.R'))
Sys.setenv(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',VECLIB_MAXIMUM_THREADS='1')
ids <- c('YL','FP'); families <- c('cauchy','maxgumbel')
variants <- c('shared_bias','shared_no_bias','duration_bias')
all_trials <- setNames(lapply(ids,function(id) {
 d <- read.csv(file.path(out,'data',paste0(id,'_model_trials.csv')))
 stopifnot(nrow(d)==4900,identical(sort(unique(d$SessionN)),1:10))
 stopifnot(all(d$StimulusOK==1),all(d$TargetOK==1),all(d$CueAssignmentOK==1))
 d
}),ids)
cat('Complete-session trial counts:\n');print(sapply(all_trials,function(d)sum(d$IsUsable==1 & is.finite(d$Precision))))
code_files <- file.path(analysis,c('cauchy_model.R','MaxGumbelModel.R','awss_runner.R'))
inputs <- c(code_files,file.path(out,'data',paste0(ids,'_model_trials.csv')))
write.csv(data.frame(path=inputs,md5=unname(tools::md5sum(inputs))),file.path(out,'input_manifest.csv'),row.names=FALSE)
legacy_file <- function(id,fam) {
 if(id=='YL') file.path(analysis,'results/YL',if(fam=='cauchy')'cauchy_awss_gaussian_decision_20starts.rds' else 'maxgumbel_awss_shared_quality_fit.rds')
 else file.path(analysis,'results/FP',if(fam=='cauchy')'cauchy_gaussian_awss_fit.rds' else 'maxgumbel_awss_fit.rds')
}
fit_path <- function(id,fam,variant)file.path(out,'fits',paste(id,fam,variant,sep='_'))
run_fit <- function(job) {
 id<-job$id;fam<-job$family;v<-job$variant
 path<-paste0(fit_path(id,fam,v),'.rds')
 if(file.exists(path)) {
   old<-readRDS(path)
   if(old$trial_count==sum(all_trials[[id]]$IsUsable==1 & is.finite(all_trials[[id]]$Precision))) return(old)
 }
 warmfile<-if(v=='shared_bias')legacy_file(id,fam) else paste0(fit_path(id,fam,'shared_bias'),'.rds')
 warm<-if(file.exists(warmfile))readRDS(warmfile) else NULL
 cat(format(Sys.time()),' START ',id,fam,v,'\n');flush.console()
 f<-fit_awss_cells(all_trials[[id]],model=fam,n=360L,n_starts=20L,
 seed=20261111L+match(id,ids)*100L+match(fam,families)*10L+match(v,variants),
 maxit=3000L,factr=1e5,pgtol=1e-7,ndeps=1e-5,
 selection=if(v=='shared_no_bias')'quality_only' else 'prefer_R',
 decision_signal=if(fam=='cauchy')'gaussian_kernel' else 'cosine',
 state_by_duration=(v=='duration_bias'),selection_by_duration=TRUE,previous_fit=warm)
 stopifnot(is.finite(f$total_negative_ll),f$trial_count==sum(all_trials[[id]]$IsUsable==1 & is.finite(all_trials[[id]]$Precision)),nrow(f$cells)==14)
 stopifnot(max(abs(f$weights$Kn_est-f$weights$ColorN*f$weights$W))<1e-10)
 mixed<-!is.na(f$weights$W_R)
 stopifnot(max(abs(f$weights$W_R[mixed]+(f$weights$ColorN[mixed]-1)*f$weights$W_NR[mixed]-f$weights$Kn_est[mixed]))<1e-10)
 f$analysis_id<-'manuscript_20261111'; f$participant<-id;f$variant<-v
 saveRDS(f,path)
 write.csv(f$starts,paste0(fit_path(id,fam,v),'_starts.csv'),row.names=FALSE)
 cat(format(Sys.time()),' DONE ',id,fam,v,'NLL',f$total_negative_ll,'parameters',f$parameter_count,'best convergence',f$convergence,'near best',sum(abs(f$starts$negative_ll-f$total_negative_ll)<.01),'of',nrow(f$starts),'\n');flush.console()
 f
}
jobs <- function(v) lapply(seq_len(nrow(expand.grid(id=ids,family=families,stringsAsFactors=FALSE))), function(i) {
 z<-expand.grid(id=ids,family=families,stringsAsFactors=FALSE)[i,];list(id=z$id,family=z$family,variant=v)
})
run_batch<-function(j) {
 ans<-parallel::mclapply(j,run_fit,mc.cores=min(4L,length(j)),mc.preschedule=FALSE,mc.set.seed=FALSE)
 bad<-vapply(ans,inherits,logical(1),'try-error')
 if(any(bad))stop(paste(ans[bad],collapse='\n'))
 invisible(ans)
}
run_batch(jobs('shared_bias'))
run_batch(c(jobs('shared_no_bias'),jobs('duration_bias')))
fitrows<-list();states<-list();weights<-list();cells<-list();comparisons<-list()
for(id in ids)for(fam in families) {
 loaded<-setNames(lapply(variants,function(v)readRDS(paste0(fit_path(id,fam,v),'.rds'))),variants)
 full<-loaded$shared_bias;none<-loaded$shared_no_bias;duration<-loaded$duration_bias
 stopifnot(full$total_negative_ll <= none$total_negative_ll + .05, duration$total_negative_ll <= full$total_negative_ll + .05)
 for(v in variants) {
  f<-loaded[[v]];n<-f$trial_count;k<-f$parameter_count
  fitrows[[length(fitrows)+1]]<-data.frame(ID=id,Family=fam,Variant=v,N=n,Parameters=k,NLL=f$total_negative_ll,AIC=2*f$total_negative_ll+2*k,BIC=2*f$total_negative_ll+k*log(n),BestConvergence=f$convergence,Starts=nrow(f$starts),NearBest=sum(abs(f$starts$negative_ll-f$total_negative_ll)<.01),ConvergedStarts=sum(f$starts$convergence==0),ElapsedSeconds=f$elapsed_seconds,SharedParameter=f$shared_parameter,SharedValue=f$shared_value)
  z<-f$state_parameters;z$ID<-id;z$Family<-fam;z$Variant<-v;states[[length(states)+1]]<-z
  z<-f$weights;z$ID<-id;z$Family<-fam;z$Variant<-v;weights[[length(weights)+1]]<-z
  z<-f$cells;z$ID<-id;z$Family<-fam;z$Variant<-v;cells[[length(cells)+1]]<-z
 }
 comparisons[[length(comparisons)+1]]<-data.frame(ID=id,Family=fam,N=full$trial_count,BiasNLLGain=none$total_negative_ll-full$total_negative_ll,BiasBICGain=(2*none$total_negative_ll+none$parameter_count*log(none$trial_count))-(2*full$total_negative_ll+full$parameter_count*log(full$trial_count)),DurationQualityNLLGain=full$total_negative_ll-duration$total_negative_ll,DurationQualityBICGain=(2*full$total_negative_ll+full$parameter_count*log(full$trial_count))-(2*duration$total_negative_ll+duration$parameter_count*log(duration$trial_count)))
}
for(nm in c('fitrows','states','weights','cells','comparisons'))write.csv(do.call(rbind,get(nm)),file.path(out,paste0(nm,'.csv')),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,'R_session_info.txt'))
print(do.call(rbind,fitrows),row.names=FALSE)
print(do.call(rbind,comparisons),row.names=FALSE)
cat('ANALYSIS COMPLETE\n')
