# Visualise mean drift (v1, v2) vs axis-aligned variability (eta1, eta2) in cdm_core.
#
# Run from POPCDM_R:
#   Rscript popcdm_v_eta_visual.R

source("popcdm300.R")

marginal_rt_from_gt <- function(Theta, Tvec, Gt) {
  w <- 2 * pi / length(Theta)
  h <- if (length(Tvec) > 1L) diff(Tvec)[1] else 1
  pt <- colSums(Gt) * w
  pt <- pmax(pt, 0)
  pt / sum(pt * h)
}

## Same geometry POPCDm uses for the canonical cdm_core call (first theta bin = -pi).
nw <- 50L
h <- 2.5 / 300
tmax <- 2.5
sigma <- 1.0
a <- 2.0
vnorm <- 2.5

Theta_grid <- -pi + (0:(nw - 1L)) * (2 * pi / nw)
v1 <- vnorm * cos(Theta_grid[1L])
v2 <- vnorm * sin(Theta_grid[1L])

## Three eta pairs: symmetric, mostly-x variability, mostly-y variability.
runs <- list(
  symmetric = c(v1, v2, 0.05, 0.05, sigma, a),
  high_eta1 = c(v1, v2, 0.18, 0.05, sigma, a),
  high_eta2 = c(v1, v2, 0.05, 0.18, sigma, a)
)

outs <- lapply(runs, function(Pi) cdm_core(Pi, nw = nw, h = h, tmax = tmax))

theta_deg <- Theta_grid * 180 / pi
cols <- c(symmetric = "#3366CC", high_eta1 = "#CC6633", high_eta2 = "#228B22")
lwds <- c(2.5, 2, 2)

png("popcdm_v_eta_fig.png", width = 1650, height = 520, res = 130)
layout(matrix(1:3, nrow = 1), widths = c(1.05, 1.2, 1.2))

## ---- Panel 1: 2D schematic -------------------------------------------------
par(mar = c(4, 4, 3, 1))
lim <- max(abs(c(v1, v2))) * 1.55 + max(runs$high_eta1[3], runs$high_eta1[4]) * 4
plot(
  NA, NA,
  xlim = c(-lim, lim), ylim = c(-lim, lim),
  asp = 1,
  xlab = "x (planar accumulation)",
  ylab = "y (planar accumulation)",
  main = "Mean drift (v1, v2) and schematic \u03b7 axes",
  las = 1
)
abline(h = 0, v = 0, col = "grey88")
grid(col = "grey92")

# Illustrative ellipse at drift tip: horizontal span ~ eta1, vertical ~ eta2 (pedagogy only).
eta_demo <- runs$high_eta1[3:4]
sc <- 6
phi <- seq(0, 2 * pi, length.out = 180)
polygon(
  v1 + sc * eta_demo[1] * cos(phi),
  v2 + sc * eta_demo[2] * sin(phi),
  border = "#CC663350", col = "#CC663318", lwd = 2
)
eta_demo2 <- runs$high_eta2[3:4]
polygon(
  v1 + sc * eta_demo2[1] * cos(phi),
  v2 + sc * eta_demo2[2] * sin(phi),
  border = "#228B2250", col = "#228B2218", lwd = 2
)

arrows(0, 0, v1, v2, length = 0.12, lwd = 3, col = "#222222")
points(0, 0, pch = 16, col = "grey45")
points(v1, v2, pch = 16, col = "#222222")

legend(
  "bottomleft",
  legend = c(
    sprintf("v = (v1, v2) = (%.2f, %.2f)", v1, v2),
    sprintf("|v| = vnorm = %.2f", sqrt(v1^2 + v2^2)),
    "Orange ellipse: larger eta1 (x-channel variability)",
    "Green ellipse: larger eta2 (y-channel variability)",
    "Ellipses are schematic (not a literal contour)."
  ),
  bty = "n", cex = 0.72
)

## ---- Panel 2: Ptheta comparison -------------------------------------------
par(mar = c(4, 4, 3, 1))
plot(
  theta_deg, outs$symmetric$Ptheta,
  type = "l", col = cols[1], lwd = lwds[1],
  xlab = expression(paste(theta, " (deg, CDM angular bins)")),
  ylab = expression(P[theta]),
  main = expression(paste("Marginal over angle: ", P[theta], " vs ", eta[1], ",", eta[2])),
  las = 1
)
lines(theta_deg, outs$high_eta1$Ptheta, col = cols[2], lwd = lwds[2])
lines(theta_deg, outs$high_eta2$Ptheta, col = cols[3], lwd = lwds[3])
grid(col = "grey92")
legend(
  "topright",
  legend = c(
    expression(paste(eta[1] == 0.05, "; ", eta[2] == 0.05)),
    expression(paste(eta[1] == 0.18, "; ", eta[2] == 0.05)),
    expression(paste(eta[1] == 0.05, "; ", eta[2] == 0.18))
  ),
  col = cols, lwd = c(2.5, 2, 2), bty = "n", cex = 0.85
)

## ---- Panel 3: marginal RT --------------------------------------------------
par(mar = c(4, 4, 3, 1))
Tref <- outs$symmetric$T
rt_sym <- marginal_rt_from_gt(Theta_grid, Tref, outs$symmetric$Gt)
rt_e1 <- marginal_rt_from_gt(Theta_grid, Tref, outs$high_eta1$Gt)
rt_e2 <- marginal_rt_from_gt(Theta_grid, Tref, outs$high_eta2$Gt)

plot(Tref, rt_sym, type = "l", col = cols[1], lwd = lwds[1],
     xlab = "Time (s)", ylab = "Approx. marginal density",
     main = sprintf("Marginal RT from Gt (fixed v = (%.2f, %.2f))", v1, v2),
     las = 1)
lines(Tref, rt_e1, col = cols[2], lwd = lwds[2])
lines(Tref, rt_e2, col = cols[3], lwd = lwds[3])
grid(col = "grey92")
legend(
  "topright",
  legend = c(
    expression(paste(eta[1] == 0.05, "; ", eta[2] == 0.05)),
    expression(paste(eta[1] == 0.18, "; ", eta[2] == 0.05)),
    expression(paste(eta[1] == 0.05, "; ", eta[2] == 0.18))
  ),
  col = cols, lwd = c(2.5, 2, 2), bty = "n", cex = 0.85
)

dev.off()

message("Wrote popcdm_v_eta_fig.png in ", normalizePath(getwd()))
