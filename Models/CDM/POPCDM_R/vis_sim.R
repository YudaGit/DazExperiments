# Visualization helpers for POPCDM simulation outputs.
# Expected input: data frame from sim_runner::sim_from_table().

# Build a compact condition key for grouping.
cond_key <- function(sim_df) {
  paste0(
    "N", sim_df$itemN,
    "_", sim_df$mode,
    "_R", sim_df$redundantN,
    "_pre", sim_df$preDur,
    "_ret", sim_df$retDur
  )
}

# Circular summary (degrees) for wrapped error in (-180, 180].
circ_summary_deg <- function(err_deg) {
  th <- err_deg * pi / 180
  cbar <- mean(cos(th), na.rm = TRUE)
  sbar <- mean(sin(th), na.rm = TRUE)
  Rbar <- sqrt(cbar^2 + sbar^2)
  mu <- atan2(sbar, cbar) * 180 / pi
  # Circular SD in radians: sqrt(-2 ln Rbar), convert to degrees.
  circ_sd <- if (Rbar > 0) sqrt(-2 * log(Rbar)) * 180 / pi else NA_real_
  list(mu_deg = mu, Rbar = Rbar, circ_sd_deg = circ_sd)
}

# Condition-wise summary table.
summarize_sim <- function(sim_df) {
  key <- cond_key(sim_df)
  groups <- split(sim_df, key)
  out <- lapply(names(groups), function(k) {
    g <- groups[[k]]
    cs <- circ_summary_deg(g$error_deg)
    qrt <- as.numeric(stats::quantile(g$rt, probs = c(0.1, 0.5, 0.9), na.rm = TRUE))
    data.frame(
      cond = k,
      n = nrow(g),
      itemN = g$itemN[1],
      mode = g$mode[1],
      redundantN = g$redundantN[1],
      preDur = g$preDur[1],
      retDur = g$retDur[1],
      mean_abs_error = mean(abs(g$error_deg), na.rm = TRUE),
      mean_rt = mean(g$rt, na.rm = TRUE),
      rt_q10 = qrt[1],
      rt_q50 = qrt[2],
      rt_q90 = qrt[3],
      err_mu_deg = cs$mu_deg,
      err_Rbar = cs$Rbar,
      err_circ_sd_deg = cs$circ_sd_deg,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

# Plot response error distribution for one condition.
plot_err_dist <- function(sim_df, cond = NULL, breaks = 36, main = NULL) {
  key <- cond_key(sim_df)
  if (is.null(cond)) cond <- unique(key)[1]
  d <- sim_df[key == cond, , drop = FALSE]
  if (!nrow(d)) stop("No rows for selected condition.", call. = FALSE)
  hist(
    d$error_deg,
    breaks = breaks,
    col = "grey80",
    border = "white",
    xlab = "Response error (deg)",
    main = if (is.null(main)) paste("Error distribution:", cond) else main
  )
  abline(v = 0, col = "red", lwd = 2)
}

# Plot RT distribution for one condition.
plot_rt_dist <- function(sim_df, cond = NULL, breaks = 30, main = NULL) {
  key <- cond_key(sim_df)
  if (is.null(cond)) cond <- unique(key)[1]
  d <- sim_df[key == cond, , drop = FALSE]
  if (!nrow(d)) stop("No rows for selected condition.", call. = FALSE)
  hist(
    d$rt,
    breaks = breaks,
    col = "skyblue",
    border = "white",
    xlab = "RT (s)",
    main = if (is.null(main)) paste("RT distribution:", cond) else main
  )
}

# Convenience: side-by-side error and RT histograms.
plot_cond_pair <- function(sim_df, cond = NULL) {
  key <- cond_key(sim_df)
  if (is.null(cond)) cond <- unique(key)[1]
  old <- par(no.readonly = TRUE)
  on.exit(par(old), add = TRUE)
  par(mfrow = c(1, 2))
  plot_err_dist(sim_df, cond = cond)
  plot_rt_dist(sim_df, cond = cond)
}

