# Visual walkthrough: pang (population layer) vs POPCDM marginals (joint hitting + mixing).
#
# Run from this directory:
#   cd POPCDM_R && Rscript popcdm_figure_walkthrough.R
# Or in R:
#   setwd("POPCDM_R"); source("popcdm_figure_walkthrough.R")

source("popcdm300.R")

## --- helpers ---------------------------------------------------------------

polar_segments <- function(theta, radii, col = "#3366CC", lwd = 2) {
  for (j in seq_along(radii)) {
    segments(
      0, 0,
      radii[j] * cos(theta[j]), radii[j] * sin(theta[j]),
      col = col, lwd = lwd
    )
  }
}

marginal_rt_from_gt <- function(Theta, Tvec, Gt) {
  w <- 2 * pi / length(Theta)
  h <- if (length(Tvec) > 1L) diff(Tvec)[1] else 1
  # p(t_k) ∝ sum_i Gt[i,k] * w  (angular marginalization), then normalize discrete bins.
  pt <- colSums(Gt) * w
  pt <- pmax(pt, 0)
  pt <- pt / sum(pt * h)
  list(t = Tvec, dens = pt)
}

## --- model run -------------------------------------------------------------

nw <- 50L
h <- 2.5 / 300
tmax <- 2.5

P_pop <- c(alpha = 2.0, kappa = 20.0)
pc <- popcode(P_pop, nw = nw)
pang <- pc$pang
Theta <- pc$th

P_full <- c(vnorm = 2.5, eta1 = 0.05, eta2 = 0.05, a = 2.0, alpha = 2.0, kappa = 20.0, ter = 0.30, st = 0.05)

out <- popcdm300(P_full, nw = nw, h = h, tmax = tmax)

# Normalize marginals for shape comparison on the circle (not equal to "same units").
pang_n <- pang / max(pang)
Ptheta_n <- out$Ptheta / max(out$Ptheta)

mr <- marginal_rt_from_gt(out$Theta, out$T, out$Gt)

## --- figure ----------------------------------------------------------------

png("popcdm_walkthrough_fig.png", width = 1600, height = 700, res = 140)

layout(matrix(1:3, nrow = 1), widths = c(1.1, 1.1, 1.2))

# (1) Population PMF pang — drift-direction weights before CDM mixture.
par(mar = c(1, 1, 3, 1))
r_max <- max(c(pang_n, Ptheta_n)) * 1.15
plot(
  0, 0, type = "n",
  xlim = c(-1, 1) * r_max, ylim = c(-1, 1) * r_max,
  asp = 1, xlab = "", ylab = "", axes = FALSE, main = "Left: pang (drift-direction weights)"
)
symbols(0, 0, circles = r_max, inches = FALSE, add = TRUE, fg = "grey85", lwd = 1)
abline(h = 0, v = 0, col = "grey92")
polar_segments(Theta, pang_n, col = "#3366CC", lwd = 2)
text(0, -r_max * 1.08, "radius = PMF scaled to max 1", cex = 0.85, col = "grey35")

# (2) Overlay pang vs Ptheta (after POPCDM): hitting spreads angle beyond drift prior.
par(mar = c(1, 1, 3, 1))
plot(
  0, 0, type = "n",
  xlim = c(-1, 1) * r_max, ylim = c(-1, 1) * r_max,
  asp = 1, xlab = "", ylab = "", axes = FALSE,
  main = "Middle: pang (blue) vs Ptheta (orange)\n(scaled separately to max 1)"
)
symbols(0, 0, circles = r_max, inches = FALSE, add = TRUE, fg = "grey85", lwd = 1)
abline(h = 0, v = 0, col = "grey92")
polar_segments(Theta, pang_n, col = "#3366CC", lwd = 2)
polar_segments(Theta, Ptheta_n, col = "#CC6633", lwd = 2)
legend(
  "topright",
  legend = c("pang (population layer)", "Ptheta (after CDM + mixture)"),
  col = c("#3366CC", "#CC6633"), lwd = 2, bty = "n", cex = 0.8
)

# (3) Marginal RT from mixed joint Gt.
par(mar = c(4, 4, 3, 1))
plot(
  mr$t, mr$dens,
  type = "l", lwd = 2, col = "#225522",
  xlab = "Time (s)", ylab = "Approx. marginal density",
  main = "Right: marginal RT from Gt\n(sum over angle bins × Δθ, normalized)"
)
grid(col = "grey90")

dev.off()

message("Wrote popcdm_walkthrough_fig.png in ", normalizePath(getwd()))
