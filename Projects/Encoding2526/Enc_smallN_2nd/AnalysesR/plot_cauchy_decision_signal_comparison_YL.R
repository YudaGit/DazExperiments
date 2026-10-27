# Plot the cells with the largest fit differences after running
# compare_cauchy_decision_signals_YL.R. Run from the Encoding2526 root.
library(ggplot2)
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
out <- "Enc_smallN_2nd/AnalysesR/results/YL"
fits <- list(cosine=readRDS(file.path(out,"cauchy_awss_cosine_decision_20starts.rds")),
             cauchy=readRDS(file.path(out,"cauchy_awss_cauchy_decision_20starts.rds")))
selected <- c("S2C2_B_50ms","S2C2_B_250ms","S4C2_R_50ms","S4C2_R_250ms")

pred <- do.call(rbind,lapply(names(fits),function(signal) {
  fit <- fits[[signal]]
  do.call(rbind,lapply(selected,function(cell) {
    row <- fit$cells[fit$cells$cell==cell,]
    P <- c(row$attended_1,row$unattended_1,row$W,fit$shared_value)
    q <- cauAWSSreport(P,360,N=row$ColorN,r=row$r,decision_signal=signal)
    data.frame(cell=cell,angle=q$theta*180/pi,density=q$ptheta*pi/180,
               signal=signal)
  }))
}))
trials <- read.csv("Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/YL_model_trials.csv")
trials <- subset(trials,IsUsable==1 & is.finite(Precision))
trials$ColorN <- ifelse(trials$RedundantN>0,
                        trials$ItemN-trials$RedundantN+1,trials$ItemN)
trials$cell <- sprintf("S%dC%d_%s_%dms",trials$ItemN,trials$ColorN,
                       trials$ConditionType,round(1000*trials$PresDur))
trials <- subset(trials,cell %in% selected)
pred$cell <- factor(pred$cell,levels=selected)
trials$cell <- factor(trials$cell,levels=selected)

p <- ggplot() +
  geom_histogram(data=trials,aes(Precision,after_stat(density)),
                 binwidth=10,boundary=-180,fill="#d6d6d6",colour="white") +
  geom_line(data=pred,aes(angle,density,colour=signal),linewidth=1) +
  facet_wrap(~cell,ncol=2) +
  coord_cartesian(xlim=c(-180,180)) +
  scale_colour_manual(values=c(cosine="#267c88",cauchy="#c25146"),
                      labels=c(cosine="Cosine decision signal",
                               cauchy="Cauchy decision signal"),name=NULL) +
  labs(title="YL: where the Cauchy-shaped decision signal loses fit",
       subtitle="Same latent-Cauchy AWSS model and 15 parameters; grey bars are observed responses",
       x="Error (degrees)",y="Density") +
  theme_minimal(base_size=14) +
  theme(panel.grid.minor=element_blank(),legend.position="bottom",
        plot.title=element_text(face="bold"))
ggsave(file.path(out,"cauchy_decision_signal_predictions_YL.png"),p,
       width=13.33,height=7.5,dpi=240,bg="white")
