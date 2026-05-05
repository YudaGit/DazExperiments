# Trial generation utilities for POPCDM simulations.

# Circular distance in degrees on [0, 360).
circ_dist_deg <- function(a, b) {
  d <- abs(a - b)
  pmin(d, 360 - d)
}

# Sample n unique hues with minimum pairwise circular separation.
sample_unique_hues <- function(n, min_sep = 30L, max_tries = 5000L) {
  if (n <= 0) return(integer(0))
  if (n == 1) return(sample.int(360L, 1L))
  if (n * min_sep > 360) {
    stop("Impossible constraint: n * min_sep > 360", call. = FALSE)
  }
  hues <- integer(0)
  tries <- 0L
  while (length(hues) < n && tries < max_tries) {
    cand <- sample.int(360L, 1L)
    if (!length(hues) || all(circ_dist_deg(cand, hues) >= min_sep)) {
      hues <- c(hues, cand)
    }
    tries <- tries + 1L
  }
  if (length(hues) < n) {
    stop("Could not sample unique hues under min_sep constraint", call. = FALSE)
  }
  hues
}

# Generate one trial array.
# mode: "baseline" (all unique), "homoR" (all redundant),
#       "R_R" (mixed, cue redundant), "R_NR" (mixed, cue nonredundant)
gen_trial <- function(
  set_size = 1:4,
  mode = c("baseline", "homoR", "R_R", "R_NR"),
  pre_dur = 0.5,
  ret_dur = 1.0,
  min_sep = 30L,
  redundant_n = 1:3L,
  even_positions = TRUE,
  seed = NULL
) {
  mode <- match.arg(mode)
  if (!is.null(seed)) set.seed(seed)
  if (set_size < 1L) stop("set_size must be >= 1", call. = FALSE)
  if (redundant_n < 1L || redundant_n > set_size) {
    stop("redundant_n must be in [1, set_size]", call. = FALSE)
  }
  # User convention:
  # baseline: redundant_n == 1 (all unique)
  # homoR: redundant_n == set_size (all same hue), only meaningful for set_size >= 2
  # mixed: 2 <= redundant_n < set_size
  if (mode == "baseline") redundant_n <- 1L
  if (mode == "homoR") redundant_n <- set_size
  if (mode == "homoR" && set_size < 2L) {
    stop("homoR is not valid for set_size < 2", call. = FALSE)
  }
  if (mode %in% c("R_R", "R_NR") && (set_size < 3L || redundant_n < 2L || redundant_n >= set_size)) {
    stop("For mixed modes: require set_size >= 3 and redundant_n in 2..set_size-1", call. = FALSE)
  }

  # 1..360 hue indices (int) for easy color-wheel mapping.
  hues <- integer(set_size)
  is_redundant <- rep(FALSE, set_size)

  if (mode == "baseline") {
    hues <- sample_unique_hues(set_size, min_sep = min_sep)
  } else if (mode == "homoR") {
    hues[] <- sample.int(360L, 1L)
    is_redundant[] <- TRUE
  } else {
    # Mixed: assign one duplicate hue to redundant positions, fill remainder unique.
    dup_h <- sample.int(360L, 1L)
    dup_pos <- sample.int(set_size, redundant_n)
    is_redundant[dup_pos] <- TRUE
    hues[dup_pos] <- dup_h
    u_pos <- which(!is_redundant)
    # Ensure uniques stay >= min_sep from duplicate hue and each other.
    filled <- integer(0)
    while (length(filled) < length(u_pos)) {
      cand <- sample.int(360L, 1L)
      if (circ_dist_deg(cand, dup_h) < min_sep) next
      if (length(filled)) {
        if (any(circ_dist_deg(cand, hues[u_pos[filled]]) < min_sep)) next
      }
      filled <- c(filled, length(filled) + 1L)
      hues[u_pos[length(filled)]] <- cand
    }
  }

  # Spatial locations on ring (degrees polar angle).
  if (even_positions) {
    base <- (0:(set_size - 1L)) * (360 / set_size)
    start <- sample.int(max(1L, floor(360 / set_size)), 1L) - 1L
    loc <- (base + start) %% 360
    loc <- sample(loc) # permute item-location pairing
  } else {
    loc <- sort(sample.int(360L, set_size, replace = FALSE) - 1L)
  }

  # Cue target index by mode.
  if (mode == "R_R") {
    pool <- which(is_redundant)
  } else if (mode == "R_NR") {
    pool <- which(!is_redundant)
  } else {
    pool <- seq_len(set_size)
  }
  target_idx <- sample(pool, 1L)

  list(
    set_size = as.integer(set_size),
    mode = mode,
    pre_dur = as.numeric(pre_dur),
    ret_dur = as.numeric(ret_dur),
    min_sep = as.integer(min_sep),
    redundant_n = as.integer(redundant_n),
    cue_type = if (mode == "R_R") "R" else if (mode == "R_NR") "NR" else NA_character_,
    hues = as.integer(hues),                # 1..360
    loc_deg = as.numeric(loc),              # 0..360
    target_idx = as.integer(target_idx),    # item index in array
    target_hue = as.integer(hues[target_idx]),
    target_loc_deg = as.numeric(loc[target_idx]),
    is_redundant = is_redundant
  )
}

# Validate multi-condition design spec used by gen_trial_table().
validate_design <- function(design) {
  need <- c("itemN", "mode", "preDur", "retDur", "min_sep", "even_positions")
  miss <- setdiff(need, names(design))
  if (length(miss)) {
    stop(sprintf("Design missing fields: %s", paste(miss, collapse = ", ")), call. = FALSE)
  }
  if (!all(design$itemN >= 1)) stop("itemN must be >= 1", call. = FALSE)
  modes_ok <- c("baseline", "homoR", "R_R", "R_NR")
  if (!all(design$mode %in% modes_ok)) {
    stop("mode must be one of baseline, homoR, R_R, R_NR", call. = FALSE)
  }
  if (is.null(design$redundantN)) {
    design$redundantN <- seq_len(max(as.integer(design$itemN)))
  }
  if (length(design$min_sep) == 1L) design$min_sep <- rep(design$min_sep, 1L)
  design
}

# Build factorial condition table from design vectors.
make_conditions <- function(design) {
  d <- validate_design(design)
  grid <- expand.grid(
    itemN = as.integer(d$itemN),
    mode = as.character(d$mode),
    redundantN = as.integer(d$redundantN),
    preDur = as.numeric(d$preDur),
    retDur = as.numeric(d$retDur),
    min_sep = as.integer(d$min_sep),
    even_positions = as.logical(d$even_positions),
    stringsAsFactors = FALSE
  )

  # Validity rules using user's conventions:
  # R=1 unique baseline; R=N homoR (only for N>=2); 2<=R<N partial redundancy (only for N>=3).
  N <- grid$itemN
  R <- grid$redundantN
  M <- grid$mode
  is_unique <- R == 1L
  is_homo <- R == N
  is_partial <- (R >= 2L) & (R < N)

  valid <- rep(TRUE, nrow(grid))
  valid <- valid & (N >= 1L) & (R >= 1L) & (R <= N)
  valid <- valid & ifelse(M == "baseline", is_unique, TRUE)
  valid <- valid & ifelse(M == "homoR", is_homo & (N >= 2L), TRUE)
  valid <- valid & ifelse(M %in% c("R_R", "R_NR"), is_partial & (N >= 3L), TRUE)

  kept <- sum(valid)
  dropped <- length(valid) - kept
  if (dropped > 0L) {
    warning(sprintf("Dropped %d invalid condition combinations; kept %d.", dropped, kept))
  }
  out <- grid[valid, , drop = FALSE]
  if (!nrow(out)) {
    stop("No valid condition combinations after filtering.", call. = FALSE)
  }
  # Keep deterministic order for readability/debugging.
  out <- out[order(out$itemN, out$mode, out$redundantN, out$preDur, out$retDur), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Generate many trials from design conditions.
# Use either reps_per_cell OR n_trials_total.
gen_trial_table <- function(
  design,
  reps_per_cell = 1L,
  n_trials_total = NULL,
  seed = NULL
) {
  if (!is.null(seed)) set.seed(seed)
  cond <- make_conditions(design)
  n_cond <- nrow(cond)
  if (n_cond < 1L) stop("No conditions generated", call. = FALSE)

  if (!is.null(n_trials_total)) {
    if (n_trials_total < 1L) stop("n_trials_total must be >= 1", call. = FALSE)
    cond_idx <- sample.int(n_cond, size = as.integer(n_trials_total), replace = TRUE)
  } else {
    if (reps_per_cell < 1L) stop("reps_per_cell must be >= 1", call. = FALSE)
    cond_idx <- rep(seq_len(n_cond), each = as.integer(reps_per_cell))
    cond_idx <- sample(cond_idx, length(cond_idx), replace = FALSE)
  }

  trials <- vector("list", length(cond_idx))
  for (i in seq_along(cond_idx)) {
    r <- cond[cond_idx[i], , drop = FALSE]
    trials[[i]] <- gen_trial(
      set_size = r$itemN,
      mode = r$mode,
      pre_dur = r$preDur,
      ret_dur = r$retDur,
      min_sep = r$min_sep,
      redundant_n = r$redundantN,
      even_positions = r$even_positions,
      seed = NULL
    )
  }

  # Compact tabular summary for downstream mapping/simulation loops.
  tab <- data.frame(
    trial_id = seq_along(trials),
    itemN = vapply(trials, function(x) x$set_size, integer(1)),
    mode = vapply(trials, function(x) x$mode, character(1)),
    redundantN = vapply(trials, function(x) x$redundant_n, integer(1)),
    cue_type = vapply(trials, function(x) ifelse(is.na(x$cue_type), "", x$cue_type), character(1)),
    preDur = vapply(trials, function(x) x$pre_dur, numeric(1)),
    retDur = vapply(trials, function(x) x$ret_dur, numeric(1)),
    min_sep = vapply(trials, function(x) x$min_sep, integer(1)),
    target_idx = vapply(trials, function(x) x$target_idx, integer(1)),
    target_hue = vapply(trials, function(x) x$target_hue, integer(1)),
    target_loc_deg = vapply(trials, function(x) x$target_loc_deg, numeric(1)),
    stringsAsFactors = FALSE
  )
  tab$hues <- I(lapply(trials, function(x) x$hues))
  tab$loc_deg <- I(lapply(trials, function(x) x$loc_deg))
  tab$is_redundant <- I(lapply(trials, function(x) x$is_redundant))

  list(
    design = design,
    conditions = cond,
    trials = trials,
    trial_table = tab
  )
}

