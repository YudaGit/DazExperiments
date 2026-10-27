# Slide figures for the Study 1 L1 illustration and the Study 2 Cauchy model.
# Run from the Encoding2526 project root with Rscript.
library(ggplot2)
library(patchwork)

out <- "Enc_smallN_2nd/AnalysesR/figures_for_lab"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
theme_set(theme_minimal(base_size = 15) +
            theme(panel.grid.minor = element_blank(),
                  panel.grid.major.x = element_blank(),
                  strip.text = element_text(face = "bold"),
                  plot.title = element_text(face = "bold")))

wrap <- function(x) ((x + pi) %% (2*pi)) - pi
wc <- function(x, k) {
  rho <- exp(-k)
  (1-rho^2)/(2*pi*(1+rho^2-2*rho*cos(x)))
}
vm <- function(x, k) exp(k*(cos(x)-1))/(2*pi*besselI(k, 0, expon.scaled=TRUE))
save_fig <- function(name, p, width=13.33, height=7.5) {
  ggsave(file.path(out, paste0(name, ".png")), p,
         width=width, height=height, units="in", dpi=240, bg="white")
}

# 1: YDL L1_2k posterior median predictions, pooled across all 10 sessions
# with weights equal to the observed trial counts in each session and cell.
cells <- read.csv("Enc_smallN_1st/AnalysesR/bayes_primary_discrete/vm_ladder_all_cell_params.csv")
cells <- subset(cells, ID=="P04" & model_id=="L1_2k")
obs <- read.csv("Enc_smallN_1st/AnalysesR/S1_smallN_model_ready.csv")
obs <- subset(obs, ID=="YDL")
counts <- aggregate(SignedErr~CueType+Duration_ms+Session,data=obs,FUN=length)
names(counts)[4] <- "trial_n"
cells <- merge(cells,counts,by.x=c("CueType","Duration_ms","SessionF"),
               by.y=c("CueType","Duration_ms","Session"))
stopifnot(nrow(cells)==140, sum(cells$trial_n)==nrow(obs))
x <- seq(-180,180,by=1)
grid <- do.call(rbind, lapply(seq_len(nrow(cells)), function(i) {
  c <- cells[i,]
  a <- x*pi/180
  data.frame(angle=x, density=((1-c$gamma)*vm(a,c$kappa)+c$gamma/(2*pi))*pi/180*c$trial_n,
             uniform=c$gamma/360*c$trial_n, trial_n=c$trial_n,
             CueType=c$CueType,
             Duration_ms=factor(c$Duration_ms,levels=seq(50,350,50)),
             gamma=c$gamma)
}))
grid <- aggregate(cbind(density,uniform,trial_n)~CueType+Duration_ms+angle,
                  data=grid,FUN=sum)
grid$density <- grid$density/grid$trial_n
grid$uniform <- grid$uniform/grid$trial_n
vm_only <- do.call(rbind,lapply(c("NR","R"),function(cue) {
  by_session <- subset(cells,CueType==cue & Duration_ms==50)
  stopifnot(nrow(by_session)==10)
  data.frame(CueType=cue,angle=x,
             vm_only=vapply(x,function(deg) mean(vm(deg*pi/180,by_session$kappa))*pi/180,numeric(1)))
}))
grid <- merge(grid,vm_only,by=c("CueType","angle"))
glabel <- subset(grid,angle == 0)[c("CueType","Duration_ms","uniform")]
glabel$label <- sprintf("U%% = %.0f%%",36000*glabel$uniform)
row_label <- subset(glabel,Duration_ms==factor(50,levels=seq(50,350,50)))
row_label$label <- row_label$CueType
obs$Duration_ms <- factor(obs$Duration_ms,levels=seq(50,350,50))
p1 <- ggplot() +
  geom_histogram(data=obs,aes(SignedErr,after_stat(density)),
                 binwidth=10,boundary=-180,fill="#d9d9d9",colour="white") +
  geom_line(data=grid,aes(angle,uniform,colour="Uniform contribution",linetype="Uniform contribution"),linewidth=1.15) +
  geom_line(data=grid,aes(angle,vm_only,colour="VM only",linetype="VM only"),linewidth=.8) +
  geom_line(data=grid,aes(angle,density,colour="Mixture prediction",linetype="Mixture prediction"),linewidth=.8) +
  geom_text(data=glabel,aes(x=170,y=Inf,label=label),inherit.aes=FALSE,
            hjust=1,vjust=1.25,size=3.3,colour="#444444") +
  geom_text(data=row_label,aes(x=-170,y=Inf,label=label),inherit.aes=FALSE,
            hjust=0,vjust=1.25,size=4,fontface="bold",colour="#20252a") +
  facet_grid(CueType~Duration_ms,scales="free_y",
             labeller=labeller(Duration_ms=function(v)paste0(v," ms"))) +
  coord_cartesian(xlim=c(-180,180)) +
  scale_x_continuous(breaks=0) +
  scale_colour_manual(values=c("Mixture prediction"="#3b929a","VM only"="#d47b26",
                               "Uniform contribution"="#202020"),name=NULL) +
  scale_linetype_manual(values=c("Mixture prediction"="solid","VM only"="dashed",
                                 "Uniform contribution"="dashed"),name=NULL) +
  labs(title="2-kappa von Mises + uniform mixture model fit to Small-N 1st Data",
       x="Error Degrees (+-180)",y="Density") +
  theme(strip.text.y=element_blank(),legend.position="bottom")
save_fig("01_study1_L1_2k_14panels_YDL_all_sessions",p1,16,7.2)

# 2: A pedagogical wrapped-Cauchy example. These parameters are illustrative.
theta <- seq(-180,170,by=10)*pi/180
h <- 10*pi/180
states <- rbind(data.frame(z=theta*180/pi,mass=wc(theta,.25)*h,state="Better state"),
                data.frame(z=theta*180/pi,mass=wc(theta,.9)*h,state="Worse state"))
states$mass <- ave(states$mass,states$state,FUN=function(v)v/sum(v))
p2 <- ggplot(states,aes(z,mass,fill=state)) +
  geom_col(width=9,show.legend=FALSE) +
  geom_vline(xintercept=0,linetype="dashed",colour="#333333") +
  facet_wrap(~state,ncol=1,scales="free_y") +
  scale_fill_manual(values=c("Better state"="#257c7e","Worse state"="#d48a44")) +
  scale_x_continuous(breaks=seq(-180,180,45)) +
  labs(title="Latent consolidated representation relative to the target",
       subtitle="Each bar is the model probability of a representation-angle bin; target = 0°",
       x="Representation angle z (degrees)",y="Probability per 10° bin")
save_fig("02_cauchy_latent_angle_bars",p2)

# 3: One illustrative trial: cosine utility, independent standard Gumbel draws,
# and the winning report angle. Gumbel noise has unit scale, not fixed values.
set.seed(20261013)
r <- seq(-180,170,by=10)
z <- 30
sens <- 7
utility <- sens*(1+cos((r-z)*pi/180))
gumbel <- -log(-log(runif(length(r))))
winner <- r[which.max(utility+gumbel)]
d3 <- rbind(data.frame(report=r,value=utility,part="1  Signal around z"),
            data.frame(report=r,value=gumbel,part="2  Independent Gumbel draws"),
            data.frame(report=r,value=utility+gumbel,part="3  Signal + noise; choose maximum"))
p3 <- ggplot(d3,aes(report,value)) +
  geom_col(aes(fill=part),width=8,show.legend=FALSE) +
  geom_vline(xintercept=z,linetype="dashed",colour="#263238") +
  geom_point(data=subset(d3,part=="3  Signal + noise; choose maximum" & report==winner),
             colour="#c33e32",size=3) +
  facet_wrap(~part,ncol=1,scales="free_y") +
  scale_fill_manual(values=c("1  Signal around z"="#257c7e",
                             "2  Independent Gumbel draws"="#9b82ae",
                             "3  Signal + noise; choose maximum"="#718d9e")) +
  scale_x_continuous(breaks=seq(-180,180,45)) +
  labs(title="Decision on one trial: Gumbel noise + maximum selection",
       subtitle=paste0("Positive signal S[1 + cos(r − z)] is choice-equivalent to the model's S[cos(r − z) − 1]; red dot = report ",winner,"°"),
       x="Possible report angle (degrees)",y="Utility or sampled noise")
save_fig("03_decision_signal_gumbel_max",p3)

# 4: Explicit weighted circular shifting and the better/worse state mixture.
# Use a 10-degree discrete circle so every bar is a probability mass.
ang <- seq(-180,170,by=10)
rad <- ang*pi/180
W <- .55
pang_b <- wc(rad,.25); pang_b <- pang_b/sum(pang_b)
pang_w <- wc(rad,.9); pang_w <- pang_w/sum(pang_w)
kernel <- exp(sens*(cos(rad)-1)); kernel <- kernel/sum(kernel)
shifted <- function(pang) {
  sapply(seq_along(ang),function(j) sum(pang *
    kernel[match(round(wrap((rad[j]-rad))*180/pi),ang)]))
}
pred_b <- shifted(pang_b); pred_w <- shifted(pang_w)
pred <- W*pred_b+(1-W)*pred_w
stopifnot(abs(sum(pred)-1)<1e-10)

left <- data.frame(z=rep(ang,2),mass=c(pang_b,pang_w),
                   state=rep(c("Better","Worse"),each=length(ang)))
pa <- ggplot(left,aes(z,mass,fill=state))+
  geom_col(width=9,position="identity",alpha=.62)+
  scale_fill_manual(values=c(Better="#257c7e",Worse="#d48a44"))+
  labs(title="1  Latent weights",x="Latent z (°)",y="P(z | state)",fill="State")+
  theme(plot.title=element_text(size=13),legend.position="bottom")

examples <- c(-40,0,40)
exidx <- match(examples,ang)
sample_curves <- do.call(rbind,lapply(exidx,function(i) {
  data.frame(report=ang,weighted=pang_b[i]*kernel[match(round(wrap(rad-rad[i])*180/pi),ang)],
             z=as.character(ang[i]))
}))
pb <- ggplot(sample_curves,aes(report,weighted,colour=z))+
  geom_line(linewidth=1)+
  scale_colour_manual(values=c("-40"="#426fbb","0"="#257c7e","40"="#aa5c75"))+
  labs(title="2  Weight shifted decisions",
       subtitle="Three better-state z values shown",
       x="Report error (°)",y="P(z) × decision mass",colour="z (°)")+
  theme(plot.title=element_text(size=13),plot.subtitle=element_text(size=10),
        legend.position="bottom")

final <- data.frame(report=rep(ang,3),mass=c(pred_b,pred_w,pred),
                    curve=rep(c("Better","Worse","Prediction"),each=length(ang)))
pc <- ggplot(final,aes(report,mass,colour=curve,linetype=curve))+
  geom_line(linewidth=1.1)+
  scale_colour_manual(values=c("Better"="#257c7e",
                               "Worse"="#d48a44",
                               "Prediction"="#20252a"))+
  scale_linetype_manual(values=c("Better"="dashed",
                                 "Worse"="dashed",
                                 "Prediction"="solid"))+
  labs(title="3  Sum z, then mix states",
       subtitle="W = 0.55 better, 0.45 worse",
       x="Report error (°)",y="Probability mass",colour=NULL,linetype=NULL)+
  theme(plot.title=element_text(size=13),plot.subtitle=element_text(size=10),
        legend.position="bottom")
p4 <- (pa|pb|pc)+plot_annotation(
  title="From latent representation to behavioural response",
  subtitle="For each state, sum P(z | state) × P(report | z) across all z; then combine states using W.")
save_fig("04_weighted_decision_convolution",p4,16,6.5)
