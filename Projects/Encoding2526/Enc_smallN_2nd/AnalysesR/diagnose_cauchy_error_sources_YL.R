# Decompose large report errors in the fitted YL Cauchy AWSS model.
# Run from the Encoding2526 project root.
source("Enc_smallN_2nd/AnalysesR/cauchy_model.R")

out <- "Enc_smallN_2nd/AnalysesR/results/YL"
fit <- readRDS(file.path(out, "cauchy_awss_cosine_decision_20starts.rds"))
cells <- fit$cells
state <- fit$state_parameters[1L, ]
cutoff <- 90

diagnose_cell <- function(cell_name) {
  row <- cells[cells$cell == cell_name, ]
  stopifnot(nrow(row) == 1L)
  pred <- cauAWSSreport(
    c(state$attended_1, state$unattended_1, row$W, fit$shared_value),
    n = 360L, N = row$ColorN, r = row$r
  )
  n <- length(pred$theta)
  angle <- pred$theta * 180 / pi
  # Joint probability for each latent direction z and report r. The decision
  # kernel is centred on z, and depends on circular report-minus-z distance.
  origin <- which.min(abs(angle))
  decision_index <- outer(seq_len(n), seq_len(n), function(r, z)
    ((r - z + origin - 1L) %% n) + 1L)
  joint <- matrix(pred$pang, nrow = n, ncol = n, byrow = TRUE) *
    matrix(pred$resp_mass[decision_index], nrow = n, ncol = n)
  stopifnot(abs(sum(joint) - 1) < 1e-10)
  far_report <- abs(angle) > cutoff
  far_z <- abs(angle) > cutoff
  far_total <- sum(joint[far_report, , drop = FALSE])
  far_with_near_z <- sum(joint[far_report, !far_z, drop = FALSE])
  far_with_far_z <- sum(joint[far_report, far_z, drop = FALSE])
  metrics <- data.frame(
    cell = cell_name,
    W = row$W,
    P_far_z = sum(pred$pang[far_z]),
    P_far_decision_given_z0 = sum(pred$resp_mass[far_report]),
    P_far_report = far_total,
    P_far_report_and_near_z = far_with_near_z,
    P_far_report_and_far_z = far_with_far_z,
    fraction_far_reports_with_far_z = far_with_far_z / far_total
  )
  list(pred = pred, metrics = metrics)
}

chosen <- c("S2C2_B_250ms", "S6C4_NR_50ms", "S6C4_R_50ms",
            "S6C4_NR_250ms", "S6C4_R_250ms")
result <- lapply(chosen, diagnose_cell)
summary <- do.call(rbind, lapply(result, `[[`, "metrics"))
write.csv(summary, file.path(out, "cauchy_error_source_diagnostic_YL.csv"),
          row.names = FALSE)
print(summary, row.names = FALSE, digits = 3)

png(file.path(out, "cauchy_error_source_diagnostic_YL.png"),
    width = 1500, height = 950, res = 150)
par(mfrow = c(2, 2), mar = c(4.2, 4.3, 3, 1), oma = c(0, 0, 1, 0))
selected <- result[c(2, 3, 4, 5)]
for (x in selected) {
  pred <- x$pred
  angle <- pred$theta * 180 / pi
  scale <- 180 / pi # probability per 1-degree bin -> density per radian
  ymax <- max(pred$pang, pred$resp_mass, pred$pred_mass) * scale * 1.07
  plot(angle, pred$pang * scale, type = "l", lwd = 2.3,
       col = "#007C91", xlim = c(-180, 180), ylim = c(0, ymax),
       xlab = "Error from true target (degrees)", ylab = "Density per radian",
       main = x$metrics$cell)
  lines(angle, pred$resp_mass * scale, col = "#E69F00", lwd = 2.3)
  lines(angle, pred$pred_mass * scale, col = "#333333", lwd = 2.3)
  abline(v = c(-90, 90), col = "#777777", lty = 3)
  legend("topright", c("Latent representation", "Decision given z = 0",
                       "Behavioural prediction"),
         col = c("#007C91", "#E69F00", "#333333"), lwd = 2.3,
         bty = "n", cex = .76)
  mtext(sprintf("Far reports with far z: %.1f%%",
                100 * x$metrics$fraction_far_reports_with_far_z),
        side = 3, line = .15, adj = 0, cex = .78)
}
dev.off()
