# Simulation runner for POPCDM.
# Produces trial-wise synthetic behavior with full trial metadata.

source("p_mapping.R")
source("popcdm300.R")

# Wrap degrees to (-180, 180].
wrap180 <- function(x) {
  y <- ((x + 180) %% 360) - 180
  ifelse(y <= -180, y + 360, y)
}

# Convert model theta radians to color-wheel degrees [1, 360].
# Theta is in [-pi, pi); map to [0, 360), then shift to 1..360 indexing.
theta_to_wheel_deg <- function(theta_rad) {
  d <- (theta_rad * 180 / pi) %% 360
  d <- ifelse(d < 0, d + 360, d)
  as.integer(round(d)) + 1L
}

# Sample one (theta_idx, time_idx) from joint density matrix Gt.
sample_from_gt <- function(T, Theta, Gt) {
  w <- 2 * pi / length(Theta)
  h <- if (length(T) > 1L) (T[2L] - T[1L]) else 1
  mass <- as.vector(Gt) * w * h
  mass[!is.finite(mass) | mass < 0] <- 0
  s <- sum(mass)
  if (s <= 0) {
    stop("sample_from_gt: non-positive total mass", call. = FALSE)
  }
  p <- mass / s
  flat_idx <- sample.int(length(p), size = 1L, prob = p)
  nr <- nrow(Gt)
  # Flattening by column: row index varies fastest.
  theta_idx <- ((flat_idx - 1L) %% nr) + 1L
  time_idx <- ((flat_idx - 1L) %/% nr) + 1L
  list(
    theta_idx = theta_idx,
    time_idx = time_idx,
    theta = Theta[theta_idx],
    rt = T[time_idx]
  )
}

# Simulate one trial from one trial object (from trial_gen::gen_trial or trial_table row unpack).
sim_one_trial <- function(trial, beta = default_beta(), nw = 50L, h = 2.5 / 300, tmax = 2.5) {
  P <- map_trial_to_params(trial, beta = beta)
  out <- popcdm300(P, nw = nw, h = h, tmax = tmax)
  draw <- sample_from_gt(out$T, out$Theta, out$Gt)

  # Response wheel degree = target hue plus sampled error angle.
  err_deg <- as.numeric(draw$theta * 180 / pi)
  target_h <- as.numeric(trial$target_hue)
  response_deg_0_360 <- (target_h + err_deg) %% 360
  response_deg <- as.integer(round(ifelse(response_deg_0_360 <= 0, response_deg_0_360 + 360, response_deg_0_360)))
  error_deg <- wrap180(response_deg - target_h)

  list(
    # trial metadata / condition factors
    itemN = as.integer(trial$set_size),
    mode = as.character(trial$mode),
    redundantN = as.integer(trial$redundant_n),
    cue_type = as.character(ifelse(is.null(trial$cue_type), "", trial$cue_type)),
    preDur = as.numeric(trial$pre_dur),
    retDur = as.numeric(trial$ret_dur),
    min_sep = as.integer(trial$min_sep),
    # full trial definition
    hues = as.integer(trial$hues),
    loc_deg = as.numeric(trial$loc_deg),
    is_redundant = as.logical(trial$is_redundant),
    target_idx = as.integer(trial$target_idx),
    target_hue = as.integer(trial$target_hue),
    target_loc_deg = as.numeric(trial$target_loc_deg),
    # mapped model parameters
    vnorm = as.numeric(P[1]),
    eta1 = as.numeric(P[2]),
    eta2 = as.numeric(P[3]),
    a = as.numeric(P[4]),
    alpha = as.numeric(P[5]),
    kappa = as.numeric(P[6]),
    ter = as.numeric(P[7]),
    st = as.numeric(P[8]),
    # sampled behavior
    theta_idx = as.integer(draw$theta_idx),
    time_idx = as.integer(draw$time_idx),
    sampled_theta_rad = as.numeric(draw$theta),
    sampled_theta_deg = err_deg,
    response_deg = as.numeric(response_deg),
    error_deg = as.numeric(error_deg),
    abs_error_deg = as.numeric(abs(error_deg)),
    rt = as.numeric(draw$rt)
  )
}

# Simulate from full trial_table output produced by trial_gen::gen_trial_table().
sim_from_table <- function(trial_table, beta = default_beta(), nw = 50L, h = 2.5 / 300, tmax = 2.5) {
  n <- nrow(trial_table)
  if (!n) stop("sim_from_table: empty trial_table", call. = FALSE)
  sim <- vector("list", n)
  for (i in seq_len(n)) {
    tr <- list(
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
    sim[[i]] <- sim_one_trial(tr, beta = beta, nw = nw, h = h, tmax = tmax)
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

