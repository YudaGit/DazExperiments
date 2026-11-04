# Compare the matched Cauchy cosine and MaxGumbel AWSS fits for FP.
# Run from the Encoding2526 project root.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")
source("Enc_smallN_2nd/AnalysesR/MaxGumbelModel.R")
library(ggplot2)
out <- "Enc_smallN_2nd/AnalysesR/results/FP"
ca <- readRDS(file.path(out, "cauchy_cosine_awss_fit.rds"))
mg <- readRDS(file.path(out, "maxgumbel_awss_fit.rds"))
stopifnot(identical(ca$cells$cell, mg$cells$cell))
trials <- read.csv(
  "Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/FP_model_trials.csv")
trials <- subset(trials, IsUsable == 1 & is.finite(Precision))
trials$ColorN <- ifelse(trials$RedundantN > 0,
                        trials$ItemN - trials$RedundantN + 1, trials$ItemN)
trials$cell <- sprintf("S%dC%d_%s_%dms", trials$ItemN, trials$ColorN,
                       trials$ConditionType, round(1000 * trials$PresDur))
ord <- with(ca$cells,
            order(ItemN, match(ConditionType, c("B", "R", "NR")), PresDur))
levels <- ca$cells$cell[ord]
trials$cell <- factor(trials$cell, levels = levels)

curves <- do.call(rbind, lapply(seq_len(nrow(ca$cells)), function(i) {
  a <- ca$cells[i, ]
  b <- mg$cells[i, ]
  ap <- cauAWSSreport(c(a$attended_1, a$unattended_1,
                        a$W, ca$shared_value), N = a$ColorN, r = a$r)
  bp <- max_gumbel_awss_report(c(b$attended_1, b$unattended_1,
                                 b$W, mg$shared_value),
                                 N = b$ColorN, r = b$r)
  rbind(data.frame(cell = a$cell, error_deg = ap$theta * 180 / pi,
                   density_deg = ap$ptheta * pi / 180,
                   model = "Cauchy AWSS"),
        data.frame(cell = b$cell, error_deg = bp$theta * 180 / pi,
                   density_deg = bp$ptheta * pi / 180,
                   model = "MaxGumbel AWSS"))
}))
curves$cell <- factor(curves$cell, levels = levels)
p <- ggplot(trials, aes(x = Precision)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 10,
                 boundary = -180, fill = "grey75", colour = "white") +
  geom_line(data = curves,
            aes(x = error_deg, y = density_deg, colour = model),
            linewidth = 0.8) +
  facet_wrap(~ cell, ncol = 4) +
  coord_cartesian(xlim = c(-180, 180)) +
  scale_x_continuous(breaks = c(-180, -90, 0, 90, 180)) +
  scale_colour_manual(values = c("Cauchy AWSS" = "#C13C32",
                                 "MaxGumbel AWSS" = "#2C7FB8")) +
  labs(x = "Signed response error (degrees)", y = "Density per degree",
       title = "FP: AWSS predictions and observed errors") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))
ggsave(file.path(out, "awss_predictions_FP.png"), p,
       width = 14, height = 11, dpi = 150)

cell_comparison <- data.frame(
  cell = ca$cells$cell,
  cauchy_negative_ll = ca$cells$negative_ll,
  maxgumbel_negative_ll = mg$cells$negative_ll
)
cell_comparison$cauchy_minus_maxgumbel <-
  cell_comparison$cauchy_negative_ll - cell_comparison$maxgumbel_negative_ll
write.csv(cell_comparison, file.path(out, "awss_cell_comparison_FP.csv"),
          row.names = FALSE)
print(cell_comparison[order(-cell_comparison$cauchy_minus_maxgumbel), ],
      row.names = FALSE)
