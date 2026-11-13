project <- normalizePath(getwd())
source(file.path(project, "Enc_smallN_2nd/AnalysesR/cauchy_model.R"))
source(file.path(project, "Enc_smallN_2nd/AnalysesR/MaxGumbelModel.R"))
library(ggplot2)
out <- file.path(project,
  "Enc_smallN_2nd/AnalysesR/results/YL/fixed_mapping_9p5deg")
ca <- readRDS(file.path(out, "cauchy_fixed_mapping_9p5deg_YL.rds"))
mg <- readRDS(file.path(out, "maxgumbel_fixed_mapping_9p5deg_YL.rds"))
trials <- read.csv(file.path(project,
  "Enc_smallN_2nd/Daz25EncodingData/PreliminaryReview/YL_model_trials.csv"))
trials <- subset(trials, IsUsable == 1 & is.finite(Precision))
trials$ColorN <- ifelse(trials$RedundantN > 0,
  trials$ItemN - trials$RedundantN + 1, trials$ItemN)
trials$cell <- sprintf("S%dC%d_%s_%dms", trials$ItemN, trials$ColorN,
                       trials$ConditionType, round(1000 * trials$PresDur))
meta <- ca$details$cells
ord <- with(meta, order(ItemN, match(ConditionType, c("B", "R", "NR")),
                        PresDur))
cell_levels <- meta$cell[ord]
trials$cell <- factor(trials$cell, levels = cell_levels)
n <- 360L
h <- 2 * pi / n
theta <- -pi + (0:(n - 1L)) * h
shift <- c(which.min(abs(theta)):n, seq_len(which.min(abs(theta)) - 1L))
distance <- abs(atan2(sin(theta), cos(theta)))
kernel <- exp(-.5 * (distance / (9.5 * pi / 180))^2)
kernel <- kernel / sum(kernel)
convolve_mass <- function(a, b) {
  v <- stats::convolve(a[shift], b[shift], type = "circular", conj = FALSE)
  v <- pmax(Re(v[order(shift)]), 0)
  v / sum(v)
}
curves <- do.call(rbind, lapply(seq_len(nrow(meta)), function(i) {
  a <- ca$details$cells[i, ]
  b <- mg$details$cells[i, ]
  ca_pred <- cauAWSSreport(c(ca$details$attended_1,
    ca$details$unattended_1, a$W_target, 9.5 * pi / 180),
    N = a$ColorN, r = a$r, decision_signal = "gaussian_kernel")
  mg_pred <- max_gumbel_awss_report(c(mg$details$attended_1,
    mg$details$unattended_1, b$W_target, mg$details$shared_value),
    N = b$ColorN, r = b$r)
  mg_mass <- convolve_mass(mg_pred$ptheta * h, kernel)
  rbind(data.frame(cell = a$cell, error_deg = theta * 180 / pi,
                   density_deg = ca_pred$ptheta * pi / 180,
                   model = "Cauchy + fixed mapping"),
        data.frame(cell = b$cell, error_deg = theta * 180 / pi,
                   density_deg = mg_mass / h * pi / 180,
                   model = "MaxGumbel + fixed mapping"))
}))
curves$cell <- factor(curves$cell, levels = cell_levels)
p <- ggplot(trials, aes(Precision)) +
  geom_histogram(aes(y = after_stat(density)), binwidth = 10,
                 boundary = -180, fill = "grey75", colour = "white") +
  geom_line(data = curves,
            aes(x = error_deg, y = density_deg, colour = model),
            linewidth = .78) +
  facet_wrap(~cell, ncol = 4) +
  coord_cartesian(xlim = c(-180, 180)) +
  scale_x_continuous(breaks = c(-180, -90, 0, 90, 180)) +
  scale_colour_manual(values = c("Cauchy + fixed mapping" = "#C13C32",
    "MaxGumbel + fixed mapping" = "#2C7FB8")) +
  labs(x = "Signed response error (degrees)", y = "Density per degree",
       title = "YL: AWSS models with response-mapping SD fixed at 9.5°") +
  theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))
ggsave(file.path(out, "fixed_mapping_9p5deg_predictions_YL.png"), p,
       width = 14, height = 11, dpi = 150)

cell_comparison <- data.frame(
  cell = meta$cell,
  Cauchy_NLL = ca$details$cells$negative_ll,
  MaxGumbel_NLL = mg$details$cells$negative_ll)
cell_comparison$Cauchy_minus_MaxGumbel <- cell_comparison$Cauchy_NLL -
  cell_comparison$MaxGumbel_NLL
write.csv(cell_comparison,
  file.path(out, "fixed_mapping_9p5deg_cell_comparison_YL.csv"),
  row.names = FALSE)
print(cell_comparison[order(-cell_comparison$Cauchy_minus_MaxGumbel), ],
      row.names = FALSE)
