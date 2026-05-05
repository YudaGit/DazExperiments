# Simulation runner for POPCDM.
# Produces trial-wise synthetic behavior with full trial metadata.

source("p_mapping.R")
source("popcdm300.R")

wrap180 <- function(x) {
  y <- ((x + 180) %% 360) - 180
  ifelse(y <= -180, y + 360, y)
}

cond_key <- function(df) {
  cue <- ifelse(df$cue_type == "" | is.na(df$cue_type), "NA", df$cue_type)
  paste0(
    "N", df$itemN,
    "_", df$mode,
    "_R", df$redundantN,
    "_cue", cue,
    "_pre", df$preDur,
    "_ret", df$retDur
  )
}

smooth_mass_matrix <- function(mass_mat, theta_bw = 1, time_bw = 1) {
  if (theta_bw <= 0 && time_bw <= 0) return(mass_mat)
  nr <- nrow(mass_mat)
  nc <- ncol(mass_mat)
  out <- matrix(0, nrow = nr, ncol = nc)
  th_idx <- seq.int(-theta_bw, theta_bw)
  tm_idx <- seq.int(-time_bw, time_bw)
  w_th <- exp(-0.5 * (th_idx / max(theta_bw, 1))^2)
  w_tm <- exp(-0.5 * (tm_idx / max(time_bw, 1))^2)
  w2 <- outer(w_th, w_tm)
  w2 <- w2 / sum(w2)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      acc <- 0
      wsum <- 0
      for (a in seq_along(th_idx)) {
        ii <- ((i - 1L + th_idx[a]) %% nr) + 1L  # circular in theta
        for (b in seq_along(tm_idx)) {
          jj <- j + tm_idx[b]
          if (jj < 1L || jj > nc) next
          ww <- w2[a, b]
          acc <- acc + ww * mass_mat[ii, jj]
          wsum <- wsum + ww
        }
      }
      out[i, j] <- if (wsum > 0) acc / wsum else 0
    }
  }
  out
}

# Joint mass over Gt cells (same normalization as previous sample_from_gt).
gt_joint_probs <- function(T, Theta, Gt, smooth = FALSE, theta_bw = 1, time_bw = 1) {
  w <- 2 * pi / length(Theta)
  h <- if (length(T) > 1L) (T[2L] - T[1L]) else 1
  mass_mat <- Gt * w * h
  mass_mat[!is.finite(mass_mat) | mass_mat < 0] <- 0
  if (smooth) {
    mass_mat <- smooth_mass_matrix(mass_mat, theta_bw = theta_bw, time_bw = time_bw)
    mass_mat[!is.finite(mass_mat) | mass_mat < 0] <- 0
  }
  mass <- as.vector(mass_mat)
  mass[!is.finite(mass) | mass < 0] <- 0
  s <- sum(mass)
  if (s <= 0) stop("gt_joint_probs: non-positive total mass", call. = FALSE)
  list(p = mass / s, nr = nrow(Gt), ntheta = length(Theta), nt = ncol(Gt))
}

# Inverse-CDF sampling on the flattened discrete joint (U ~ Unif(0,1) -> cell index).
sample_n_from_gt <- function(
    T, Theta, Gt, n,
    smooth = FALSE,
    theta_bw = 1,
    time_bw = 1) {
  if (n < 1L) stop("sample_n_from_gt: n >= 1 required", call. = FALSE)
  jp <- gt_joint_probs(T, Theta, Gt, smooth = smooth, theta_bw = theta_bw, time_bw = time_bw)
  u <- stats::runif(n)
  cp <- cumsum(jp$p)
  flat_idx <- vapply(u, function(ui) sum(cp < ui) + 1L, integer(1))
  flat_idx <- pmin(flat_idx, length(jp$p))
  nr <- jp$nr
  theta_idx <- ((flat_idx - 1L) %% nr) + 1L
  time_idx <- ((flat_idx - 1L) %/% nr) + 1L
  list(
    theta_idx = theta_idx,
    time_idx = time_idx,
    theta = Theta[theta_idx],
    rt = T[time_idx]
  )
}

sample_from_gt <- function(T, Theta, Gt, smooth = FALSE, theta_bw = 1, time_bw = 1) {
  sample_n_from_gt(T, Theta, Gt, 1L, smooth = smooth, theta_bw = theta_bw, time_bw = time_bw)
}

trial_from_table_row <- function(trial_table, i) {
  list(
    set_size = as.integer(trial_table$itemN[i]),
    mode = as.character(trial_table$mode[i]),
    redundant_n = as.integer(trial_table$redundantN[i]),
    cue_type = ifelse(nchar(trial_table$cue_type[i]) == 0, NA_character_, as.character(trial_table$cue_type[i])),
    pre_dur = as.numeric(trial_table$preDur[i]),
    ret_dur = as.numeric(trial_table$retDur[i]),
    min_sep = as.integer(trial_table$min_sep[i]),
    hues = as.integer(trial_table$hues[[i]]),
    loc_deg = as.numeric(trial_table$loc_deg[[i]]),
    is_redundant = as.logical(trial_table$is_redundant[[i]]),
    target_idx = as.integer(trial_table$target_idx[i]),
    target_hue = as.integer(trial_table$target_hue[i]),
    target_loc_deg = as.numeric(trial_table$target_loc_deg[i])
  )
}

sim_one_draw <- function(trial, draw, sim_mode = c("error_only", "response")) {
  sim_mode <- match.arg(sim_mode)
  err_deg_raw <- as.numeric(draw$theta * 180 / pi)
  if (sim_mode == "error_only") {
    error_deg <- wrap180(err_deg_raw)
    response_deg <- NA_real_
  } else {
    target_h <- as.numeric(trial$target_hue)
    response_deg_0_360 <- (target_h + err_deg_raw) %% 360
    response_deg <- as.integer(round(ifelse(response_deg_0_360 <= 0, response_deg_0_360 + 360, response_deg_0_360)))
    error_deg <- wrap180(response_deg - target_h)
  }
  list(
    response_deg = as.numeric(response_deg),
    error_deg = as.numeric(error_deg),
    abs_error_deg = as.numeric(abs(error_deg)),
    rt = as.numeric(draw$rt),
    theta_idx = as.integer(draw$theta_idx),
    time_idx = as.integer(draw$time_idx),
    sampled_theta_rad = as.numeric(draw$theta),
    sampled_theta_deg = err_deg_raw
  )
}

assemble_sim_row <- function(trial, P, beh) {
  list(
    itemN = as.integer(trial$set_size),
    mode = as.character(trial$mode),
    redundantN = as.integer(trial$redundant_n),
    cue_type = as.character(ifelse(is.null(trial$cue_type), "", trial$cue_type)),
    preDur = as.numeric(trial$pre_dur),
    retDur = as.numeric(trial$ret_dur),
    min_sep = as.integer(trial$min_sep),
    hues = as.integer(trial$hues),
    loc_deg = as.numeric(trial$loc_deg),
    is_redundant = as.logical(trial$is_redundant),
    target_idx = as.integer(trial$target_idx),
    target_hue = as.integer(trial$target_hue),
    target_loc_deg = as.numeric(trial$target_loc_deg),
    vnorm = as.numeric(P[1]),
    eta1 = as.numeric(P[2]),
    eta2 = as.numeric(P[3]),
    a = as.numeric(P[4]),
    alpha = as.numeric(P[5]),
    kappa = as.numeric(P[6]),
    ter = as.numeric(P[7]),
    st = as.numeric(P[8]),
    theta_idx = beh$theta_idx,
    time_idx = beh$time_idx,
    sampled_theta_rad = beh$sampled_theta_rad,
    sampled_theta_deg = beh$sampled_theta_deg,
    response_deg = beh$response_deg,
    error_deg = beh$error_deg,
    abs_error_deg = beh$abs_error_deg,
    rt = beh$rt
  )
}

# Population scaling: pop_tune = "alpha" or "kappa" (see p_mapping.R).
sim_one_trial <- function(
    trial,
    beta = default_beta(),
    pop_tune = c("alpha", "kappa"),
    sim_mode = c("error_only", "response"),
    smooth_gt = TRUE,
    smooth_theta_bw = 1,
    smooth_time_bw = 1,
    nw = 50L,
    h = 2.5 / 300,
    tmax = 2.5) {
  pop_tune <- match.arg(pop_tune)
  sim_mode <- match.arg(sim_mode)
  P <- map_trial_to_params(trial, beta = beta, pop_tune = pop_tune)
  out <- popcdm300(P, nw = nw, h = h, tmax = tmax)
  draw <- sample_from_gt(out$T, out$Theta, out$Gt, smooth = smooth_gt, theta_bw = smooth_theta_bw, time_bw = smooth_time_bw)
  beh <- sim_one_draw(trial, draw, sim_mode = sim_mode)
  assemble_sim_row(trial, P, beh)
}

pop_params_key <- function(itemN, mode, redundantN, pop_tune) {
  paste(itemN, mode, redundantN, pop_tune, sep = "|")
}

# Group trials that share the same P(itemN, mode, redundantN, pop_tune): one popcdm300,
# then many inverse-CDF draws from the same joint (reuse_dist = TRUE).
sim_from_table <- function(
    trial_table,
    beta = default_beta(),
    pop_tune = c("alpha", "kappa"),
    sim_mode = c("error_only", "response"),
    smooth_gt = TRUE,
    smooth_theta_bw = 1,
    smooth_time_bw = 1,
    nw = 50L,
    h = 2.5 / 300,
    tmax = 2.5,
    reuse_dist = TRUE) {
  pop_tune <- match.arg(pop_tune)
  sim_mode <- match.arg(sim_mode)
  n <- nrow(trial_table)
  if (!n) stop("sim_from_table: empty trial_table", call. = FALSE)

  sim <- vector("list", n)

  if (!reuse_dist) {
    for (i in seq_len(n)) {
      tr <- trial_from_table_row(trial_table, i)
      sim[[i]] <- sim_one_trial(
        tr, beta = beta, pop_tune = pop_tune, sim_mode = sim_mode,
        smooth_gt = smooth_gt, smooth_theta_bw = smooth_theta_bw, smooth_time_bw = smooth_time_bw,
        nw = nw, h = h, tmax = tmax
      )
    }
  } else {
    keys <- mapply(
      pop_params_key,
      trial_table$itemN,
      trial_table$mode,
      trial_table$redundantN,
      MoreArgs = list(pop_tune = pop_tune),
      USE.NAMES = FALSE
    )
    for (k in unique(keys)) {
      idx <- which(keys == k)
      tr0 <- trial_from_table_row(trial_table, idx[1L])
      P <- map_trial_to_params(tr0, beta = beta, pop_tune = pop_tune)
      out <- popcdm300(P, nw = nw, h = h, tmax = tmax)
      draws <- sample_n_from_gt(
        out$T, out$Theta, out$Gt, length(idx),
        smooth = smooth_gt, theta_bw = smooth_theta_bw, time_bw = smooth_time_bw
      )
      for (j in seq_along(idx)) {
        tr <- trial_from_table_row(trial_table, idx[j])
        draw <- list(
          theta_idx = draws$theta_idx[j],
          time_idx = draws$time_idx[j],
          theta = draws$theta[j],
          rt = draws$rt[j]
        )
        beh <- sim_one_draw(tr, draw, sim_mode = sim_mode)
        sim[[idx[j]]] <- assemble_sim_row(tr, P, beh)
      }
    }
  }

  out <- data.frame(
    trial_id = seq_len(n),
    itemN = vapply(sim, function(x) x$itemN, integer(1)),
    mode = vapply(sim, function(x) x$mode, character(1)),
    redundantN = vapply(sim, function(x) x$redundantN, integer(1)),
    cue_type = vapply(sim, function(x) x$cue_type, character(1)),
    preDur = vapply(sim, function(x) x$preDur, numeric(1)),
    retDur = vapply(sim, function(x) x$retDur, numeric(1)),
    min_sep = vapply(sim, function(x) x$min_sep, integer(1)),
    target_idx = vapply(sim, function(x) x$target_idx, integer(1)),
    target_hue = vapply(sim, function(x) x$target_hue, integer(1)),
    target_loc_deg = vapply(sim, function(x) x$target_loc_deg, numeric(1)),
    response_deg = vapply(sim, function(x) x$response_deg, numeric(1)),
    error_deg = vapply(sim, function(x) x$error_deg, numeric(1)),
    abs_error_deg = vapply(sim, function(x) x$abs_error_deg, numeric(1)),
    rt = vapply(sim, function(x) x$rt, numeric(1)),
    vnorm = vapply(sim, function(x) x$vnorm, numeric(1)),
    eta1 = vapply(sim, function(x) x$eta1, numeric(1)),
    eta2 = vapply(sim, function(x) x$eta2, numeric(1)),
    a = vapply(sim, function(x) x$a, numeric(1)),
    alpha = vapply(sim, function(x) x$alpha, numeric(1)),
    kappa = vapply(sim, function(x) x$kappa, numeric(1)),
    ter = vapply(sim, function(x) x$ter, numeric(1)),
    st = vapply(sim, function(x) x$st, numeric(1)),
    stringsAsFactors = FALSE
  )
  out$hues <- I(lapply(sim, function(x) x$hues))
  out$loc_deg <- I(lapply(sim, function(x) x$loc_deg))
  out$is_redundant <- I(lapply(sim, function(x) x$is_redundant))
  out
}

plot_cond_pair <- function(sim_df, cond, err_breaks = 36, rt_breaks = 30) {
  d <- sim_df[cond_key(sim_df) == cond, , drop = FALSE]
  if (!nrow(d)) stop("No rows for condition in plot_cond_pair", call. = FALSE)
  old <- par(no.readonly = TRUE)
  on.exit(par(old), add = TRUE)
  par(mfrow = c(1, 2))
  hist(
    d$error_deg,
    breaks = err_breaks,
    col = "grey80",
    border = "white",
    xlab = "Response error (deg)",
    main = paste("Error:", cond)
  )
  abline(v = 0, col = "red", lwd = 2)
  hist(
    d$rt,
    breaks = rt_breaks,
    col = "skyblue",
    border = "white",
    xlab = "RT (s)",
    main = paste("RT:", cond)
  )
}

plot_all_cond_pairs <- function(sim_df, out_file = NULL, err_breaks = 36, rt_breaks = 30) {
  conds <- unique(cond_key(sim_df))
  n <- length(conds)
  if (!n) stop("plot_all_cond_pairs: no conditions found", call. = FALSE)
  if (!is.null(out_file)) {
    grDevices::pdf(out_file, width = 10, height = 4)
    on.exit(grDevices::dev.off(), add = TRUE)
  }
  old <- par(no.readonly = TRUE)
  on.exit(par(old), add = TRUE)
  for (cnd in conds) {
    plot_cond_pair(sim_df, cond = cnd, err_breaks = err_breaks, rt_breaks = rt_breaks)
  }
  invisible(conds)
}
