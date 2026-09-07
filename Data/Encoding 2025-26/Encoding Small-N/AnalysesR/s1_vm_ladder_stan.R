# =============================================================================
# Bayesian hierarchical von Mises mixture ladder (Stan / cmdstanr)
# =============================================================================
# Levels:
#   L0 — VM(0, kappa) only
#   L1 — VM + uniform guess (gamma)
#   L2 — VM + swap (3 non-target bumps) + uniform guess
# Kappa structure per fit: "2k" (by CueType) or "14k" (Cue x Duration).
# Session nested: additive offsets on log-kappa / logit-gamma / logit-beta (S1 ref).
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(cmdstanr)
  library(loo)
  library(posterior)
})

# Plot defaults for Section 3 chunks (safe if Section 2 descriptives not run).
vm_ladder_plot_defaults <- function() {
  cue_cols <- c("NR" = "#6B9AC4", "R" = "#C75146")
  desc_font <- if (
    requireNamespace("systemfonts", quietly = TRUE) &&
      "Times New Roman" %in% unique(systemfonts::system_fonts()$family)
  ) {
    "Times New Roman"
  } else {
    "Times"
  }
  theme_desc <- theme_bw(base_size = 11, base_family = desc_font) +
    theme(
      panel.grid.minor = element_blank(),
      strip.placement = "inside",
      strip.background = element_blank(),
      strip.text = element_text(face = "bold", hjust = 0.5, vjust = 0),
      legend.position = "bottom",
      legend.title = element_text(face = "bold"),
      plot.title = element_blank(),
      text = element_text(family = desc_font),
      axis.title = element_text(family = desc_font),
      axis.text = element_text(family = desc_font),
      legend.text = element_text(family = desc_font)
    )
  list(cue_cols = cue_cols, theme_desc = theme_desc)
}

vm_init_plot_defaults <- function() {
  if (!exists("cue_cols", envir = .GlobalEnv) || !exists("theme_desc", envir = .GlobalEnv)) {
    defs <- vm_ladder_plot_defaults()
    assign("cue_cols", defs$cue_cols, envir = .GlobalEnv)
    assign("theme_desc", defs$theme_desc, envir = .GlobalEnv)
  }
  invisible(NULL)
}

# Pool session-nested cells to Cue×Duration for plotting (median of cell CIs).
vm_summarise_cells_plot <- function(df, param = c("kappa", "gamma", "beta")) {
  param <- match.arg(param)
  med <- paste0(param, "_median")
  lo <- paste0(param, "_lower")
  hi <- paste0(param, "_upper")
  id_cols <- intersect(
    c("ID", "model_id", "CueType", "DurationF"),
    names(df)
  )
  df %>%
    mutate(Duration_ms = as.numeric(gsub("ms", "", as.character(DurationF)))) %>%
    group_by(across(all_of(id_cols))) %>%
    summarise(
      Duration_ms = first(Duration_ms),
      estimate = median(.data[[med]], na.rm = TRUE),
      lower = median(.data[[lo]], na.rm = TRUE),
      upper = median(.data[[hi]], na.rm = TRUE),
      .groups = "drop"
    )
}

# ---- circular helpers ----

wrap_rad_from_deg <- function(deg) {
  atan2(sin(deg * pi / 180), cos(deg * pi / 180))
}

circ_sd_from_kappa <- function(kappa) {
  a <- pmax(
    besselI(kappa, 1, expon.scaled = TRUE) /
      pmax(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin),
    1e-12
  )
  a <- pmin(a, 1 - 1e-12)
  sqrt(-2 * log(a)) * (180 / pi)
}

# Stan parameters to summarise / extract (exclude per-trial log_lik).
vm_stan_param_vars <- function(level = c("L0", "L1", "L2")) {
  level <- match.arg(level)
  vars <- c("log_kappa_base", "log_kappa_sess")
  if (level == "L1") {
    vars <- c(vars, "gamma_cd_logit", "gamma_sess_logit")
  }
  if (level == "L2") {
    vars <- c(vars, "beta_cd_logit", "beta_sess_logit", "gfrac_cd_logit", "gfrac_sess_logit")
  }
  vars
}

vm_fetch_param_draws <- function(fit, level) {
  as.matrix(fit$draws(variables = vm_stan_param_vars(level), format = "matrix"))
}

vm_get_param_draws <- function(fit_obj) {
  if (!is.null(fit_obj$param_draws)) {
    return(fit_obj$param_draws)
  }
  if (!is.null(fit_obj$fit)) {
    return(vm_fetch_param_draws(fit_obj$fit, fit_obj$level))
  }
  stop("No parameter draws in fit cache", call. = FALSE)
}

prune_vm_stan_chain_files <- function(out_dir, verbose = TRUE) {
  if (!dir.exists(out_dir)) {
    return(invisible(0L))
  }
  files <- list.files(out_dir, full.names = TRUE, recursive = FALSE)
  drop <- files[grepl("vm_ladder_.*\\.(csv|json)$", basename(files), ignore.case = TRUE) |
    grepl("-profile-", basename(files), fixed = TRUE)]
  if (length(drop) == 0L) {
    return(invisible(0L))
  }
  removed <- file.remove(drop)
  if (verbose) {
    message("Pruned ", sum(removed), " chain/diagnostic file(s) from ", out_dir)
  }
  invisible(sum(removed))
}

slim_vm_fit_meta <- function(
    fit_obj,
    save = TRUE,
    delete_chains = TRUE,
    verbose = TRUE
) {
  if (isTRUE(fit_obj$slim)) {
    return(fit_obj)
  }

  param_draws <- vm_get_param_draws(fit_obj)
  cell_params <- extract_vm_cell_params_from_draws(fit_obj, param_draws)

  slim <- list(
    slim = TRUE,
    model_id = fit_obj$model_id,
    level = fit_obj$level,
    kappa_struct = fit_obj$kappa_struct,
    raw_id = fit_obj$raw_id,
    out_dir = fit_obj$out_dir,
    prep = fit_obj$prep,
    stan_data = fit_obj$stan_data,
    elapsed_min = fit_obj$elapsed_min,
    loo = fit_obj$loo,
    waic = fit_obj$waic,
    summary = fit_obj$summary,
    param_draws = param_draws,
    cell_params = cell_params
  )

  if (save && !is.null(fit_obj$out_dir)) {
    saveRDS(slim, file.path(fit_obj$out_dir, "fit_meta.rds"))
  }
  if (delete_chains && !is.null(fit_obj$out_dir)) {
    prune_vm_stan_chain_files(fit_obj$out_dir, verbose = verbose)
  }
  slim
}

prune_vm_stan_cache <- function(
    root = file.path("bayes_primary_discrete", "vm_stan"),
    remove_smoke = TRUE,
    verbose = TRUE
) {
  dirs <- list.dirs(root, full.names = TRUE, recursive = FALSE)
  if (remove_smoke) {
    smoke <- dirs[grepl("^_", basename(dirs))]
    for (d in smoke) {
      if (verbose) message("Removing smoke folder: ", d)
      unlink(d, recursive = TRUE)
    }
    dirs <- setdiff(dirs, smoke)
  }

  out <- list()
  for (d in dirs) {
    meta <- file.path(d, "fit_meta.rds")
    if (!file.exists(meta)) next
    x <- readRDS(meta)
    out[[basename(d)]] <- slim_vm_fit_meta(
      x, save = TRUE, delete_chains = TRUE, verbose = verbose
    )
  }
  invisible(out)
}

vm_param_matrix <- function(draw_mat, pattern) {
  draw_mat <- as.matrix(draw_mat)
  cols <- grep(pattern, colnames(draw_mat), value = FALSE)
  if (length(cols) == 0) {
    matrix(0, nrow = nrow(draw_mat), ncol = 0)
  } else {
    as.matrix(draw_mat[, cols, drop = FALSE])
  }
}

vm_build_cell_draws <- function(base_mat, idx, sess_mat, idx_sess) {
  base_mat <- as.matrix(base_mat)
  sess_mat <- as.matrix(sess_mat)
  out <- as.matrix(base_mat[, idx, drop = FALSE])
  if (ncol(sess_mat) > 0) {
    for (s in seq_len(ncol(sess_mat))) {
      cols <- which(idx_sess == s + 1L)
      if (length(cols) > 0) {
        for (col in cols) {
          out[, col] <- out[, col] + sess_mat[, s]
        }
      }
    }
  }
  out
}

vm_summarise_draw_mat <- function(draw_mat, transform = identity) {
  x <- as.matrix(transform(as.matrix(draw_mat)))
  tibble(
    median = colMedians(x),
    lower = apply(x, 2, stats::quantile, 0.025),
    upper = apply(x, 2, stats::quantile, 0.975)
  )
}

# ---- trial prep (swap centres for L2) ----

prep_vm_trials <- function(d_sub) {
  stopifnot(nrow(d_sub) > 0)
  cues <- levels(d_sub$CueType)
  durs <- levels(d_sub$DurationF)
  sess <- levels(d_sub$SessionF)

  d_sub <- d_sub %>%
    mutate(
      theta = wrap_rad_from_deg(SignedErr),
      idx_cue = as.integer(CueType),
      idx_dur = as.integer(DurationF),
      idx_cd = (idx_cue - 1L) * length(durs) + idx_dur,
      idx_sess = as.integer(SessionF)
    )

  n <- nrow(d_sub)
  mu1 <- mu2 <- mu3 <- numeric(n)
  item_mat <- as.matrix(d_sub[, paste0("ItemHue", 1:6)])

  for (t in seq_len(n)) {
    target <- d_sub$TargetHue[t]
    hues <- unique(as.numeric(item_mat[t, ]))
    nontarget <- hues[abs(wrap_rad_from_deg(hues - target)) > 1e-8]
    stopifnot(length(nontarget) == 3)
    mu <- wrap_rad_from_deg(target - nontarget)
    mu1[t] <- mu[1]
    mu2[t] <- mu[2]
    mu3[t] <- mu[3]
  }

  list(
    data = d_sub,
    theta = d_sub$theta,
    mu1 = mu1,
    mu2 = mu2,
    mu3 = mu3,
    idx_cue = d_sub$idx_cue,
    idx_cd = d_sub$idx_cd,
    idx_sess = d_sub$idx_sess,
    n = n,
    n_cd = length(cues) * length(durs),
    n_sess = length(sess),
    n_cue = length(cues)
  )
}

prep_stan_data <- function(d_sub, level, kappa_struct = c("2k", "14k")) {
  kappa_struct <- match.arg(kappa_struct)
  prep <- prep_vm_trials(d_sub)
  kappa_idx <- if (kappa_struct == "2k") prep$idx_cue else prep$idx_cd
  n_kappa <- if (kappa_struct == "2k") prep$n_cue else prep$n_cd

  stan_data <- list(
    N = prep$n,
    theta = prep$theta,
    idx_cd = prep$idx_cd,
    idx_sess = prep$idx_sess,
    kappa_idx = kappa_idx,
    n_kappa = n_kappa,
    n_cd = prep$n_cd,
    n_sess = prep$n_sess
  )

  if (level == "L2") {
    stan_data$mu1 <- prep$mu1
    stan_data$mu2 <- prep$mu2
    stan_data$mu3 <- prep$mu3
  }

  list(stan_data = stan_data, prep = prep, kappa_struct = kappa_struct, level = level)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---- Stan model cache ----

.vm_stan_models <- new.env(parent = emptyenv())

get_vm_stan_model <- function(level) {
  level <- match.arg(level, c("L0", "L1", "L2"))
  if (!exists(level, envir = .vm_stan_models)) {
    stan_file <- file.path("stan", paste0("vm_ladder_", level, ".stan"))
    message("Compiling Stan model: ", stan_file)
    assign(level, cmdstan_model(stan_file), envir = .vm_stan_models)
  }
  get(level, envir = .vm_stan_models)
}

# Single batch job (top-level for cluster export).
vm_stan_fit_job <- function(
    raw,
    kappa_struct,
    vm_data,
    level,
    kappa_structs,
    raw_ids,
    parallel_chains,
    chains,
    seed = 1234,
    ...
) {
  raw <- as.character(raw)
  kappa_struct <- as.character(kappa_struct)
  seed_extra <- match(kappa_struct, kappa_structs)
  raw_extra <- match(raw, raw_ids)
  job_seed <- seed + 10L * raw_extra + seed_extra

  fit_vm_stan(
    vm_data[[raw]],
    level = level,
    kappa_struct = kappa_struct,
    raw_id = raw,
    chains = chains,
    parallel_chains = parallel_chains,
    seed = job_seed,
    ...
  )
}

.assert_vm_fit_result <- function(res, label = "fit") {
  if (inherits(res, "try-error")) {
    stop(attr(res, "condition")$message, call. = FALSE)
  }
  if (is.character(res) && length(res) == 1L) {
    stop(res, call. = FALSE)
  }
  if (!is.list(res) || is.null(res$model_id)) {
    stop(
      label, " did not return a valid fit list (got: ", paste(class(res), collapse = ", "), ")",
      call. = FALSE
    )
  }
  invisible(res)
}

# ---- fit ----

fit_vm_stan <- function(
    d_sub,
    level = c("L0", "L1", "L2"),
    kappa_struct = c("2k", "14k"),
    raw_id = NA_character_,
    out_dir = NULL,
    chains = 4,
    parallel_chains = min(4L, parallel::detectCores()),
    iter_warmup = 2000,
    iter_sampling = 2000,
    adapt_delta = 0.95,
    max_treedepth = 12,
    refresh = 100,
    seed = 1234,
    force_refit = FALSE
) {
  level <- match.arg(level)
  kappa_struct <- match.arg(kappa_struct)
  model_id <- paste0(level, "_", kappa_struct)
  label <- paste0(if (!is.na(raw_id)) paste0(raw_id, ": "), model_id)

  if (is.null(out_dir)) {
    out_dir <- file.path(
      "bayes_primary_discrete", "vm_stan",
      paste0(if (!is.na(raw_id)) raw_id else "fit", "_", model_id)
    )
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  meta_file <- file.path(out_dir, "fit_meta.rds")
  if (!force_refit && file.exists(meta_file)) {
    message("Loading cached Stan fit: ", out_dir)
    return(readRDS(meta_file))
  }

  message("=== Fitting ", label, " (n = ", nrow(d_sub), " trials) ===")
  bundled <- prep_stan_data(d_sub, level, kappa_struct)
  mod <- get_vm_stan_model(level)

  t0 <- Sys.time()
  fit <- mod$sample(
    data = bundled$stan_data,
    chains = chains,
    parallel_chains = parallel_chains,
    iter_warmup = iter_warmup,
    iter_sampling = iter_sampling,
    adapt_delta = adapt_delta,
    max_treedepth = max_treedepth,
    refresh = refresh,
    seed = seed,
    output_dir = out_dir
  )
  elapsed_min <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  message("Finished ", label, " in ", round(elapsed_min, 1), " min")

  loo_res <- tryCatch({
    ll <- fit$draws("log_lik", format = "matrix")
    loo(ll)
  }, error = function(e) {
    message("LOO failed: ", conditionMessage(e))
    NULL
  })

  waic_res <- tryCatch(waic(fit$draws("log_lik", format = "matrix")), error = function(e) NULL)

  result <- list(
    model_id = model_id,
    level = level,
    kappa_struct = kappa_struct,
    raw_id = raw_id,
    out_dir = out_dir,
    fit = fit,
    stan_data = bundled$stan_data,
    prep = bundled$prep,
    elapsed_min = elapsed_min,
    loo = loo_res,
    waic = waic_res,
    summary = fit$summary(variables = vm_stan_param_vars(level))
  )
  result <- slim_vm_fit_meta(result, save = TRUE, delete_chains = TRUE, verbose = TRUE)
  result
}

# ---- fit all specs for one level ----

fit_vm_level <- function(
    d_sub,
    level,
    raw_id,
    kappa_structs = c("2k", "14k"),
    ...
) {
  fits <- list()
  for (ks in kappa_structs) {
    fits[[paste0(level, "_", ks)]] <- fit_vm_stan(
      d_sub, level = level, kappa_struct = ks, raw_id = raw_id, ...
    )
  }
  cmp <- map_dfr(fits, function(x) {
    tibble(
      model_id = x$model_id,
      level = x$level,
      kappa_struct = x$kappa_struct,
      elapsed_min = x$elapsed_min,
      elpd_loo = if (!is.null(x$loo)) x$loo$estimates["elpd_loo", "Estimate"] else NA_real_,
      se_loo = if (!is.null(x$loo)) x$loo$estimates["elpd_loo", "SE"] else NA_real_,
      looic = if (!is.null(x$loo)) x$loo$estimates["looic", "Estimate"] else NA_real_,
      waic = if (!is.null(x$waic)) x$waic$estimates["waic", "Estimate"] else NA_real_
    )
  }) %>%
    mutate(
      delta_loo = -elpd_loo + max(elpd_loo, na.rm = TRUE),
      delta_waic = waic - min(waic, na.rm = TRUE)
    ) %>%
    arrange(delta_loo)

  list(fits = fits, compare = cmp)
}

# ---- parallel plan: model workers × chains per fit ≤ available cores ----

vm_stan_parallel_plan <- function(
    n_cores = parallel::detectCores(),
    chains_per_fit = 4L,
    n_workers = NULL
) {
  n_cores <- as.integer(max(1L, n_cores))
  chains_per_fit <- as.integer(max(1L, chains_per_fit))

  if (is.null(n_workers)) {
    n_workers <- max(1L, n_cores %/% chains_per_fit)
  } else {
    n_workers <- as.integer(max(1L, n_workers))
  }

  # If user asks for more workers than cores allow, reduce chains per fit.
  parallel_chains <- min(chains_per_fit, max(1L, n_cores %/% n_workers))
  n_workers <- min(n_workers, max(1L, n_cores %/% parallel_chains))

  list(
    n_cores = n_cores,
    n_workers = n_workers,
    parallel_chains = parallel_chains,
    n_cores_used = n_workers * parallel_chains
  )
}

print_vm_stan_parallel_plan <- function(plan) {
  message(
    "Stan parallel plan: ", plan$n_workers, " model worker(s) × ",
    plan$parallel_chains, " chain(s) each (", plan$n_cores_used, " / ",
    plan$n_cores, " cores)"
  )
}

# Fit all participants × kappa structures for one ladder level (parallel across jobs).
fit_vm_ladder_batch <- function(
    vm_data,
    level = c("L0", "L1", "L2"),
    raw_ids,
    id_pub,
    kappa_structs = c("2k", "14k"),
    n_workers = NULL,
    chains = 4L,
    ...
) {
  level <- match.arg(level)
  get_vm_stan_model(level) # compile once in the parent process

  plan <- vm_stan_parallel_plan(
    n_cores = parallel::detectCores(),
    chains_per_fit = chains,
    n_workers = n_workers
  )
  print_vm_stan_parallel_plan(plan)

  jobs <- expand_grid(
    raw = raw_ids,
    kappa_struct = kappa_structs,
    .name_repair = "minimal"
  )
  jobs$raw <- as.character(jobs$raw)
  jobs$kappa_struct <- as.character(jobs$kappa_struct)

  fit_args <- list(...)
  if (is.null(fit_args$seed)) fit_args$seed <- 1234L

  run_one <- function(i) {
    res <- vm_stan_fit_job(
      raw = jobs$raw[i],
      kappa_struct = jobs$kappa_struct[i],
      vm_data = vm_data,
      level = level,
      kappa_structs = kappa_structs,
      raw_ids = raw_ids,
      parallel_chains = plan$parallel_chains,
      chains = chains,
      seed = fit_args$seed,
      iter_warmup = fit_args$iter_warmup,
      iter_sampling = fit_args$iter_sampling,
      adapt_delta = fit_args$adapt_delta,
      max_treedepth = fit_args$max_treedepth,
      refresh = fit_args$refresh,
      force_refit = isTRUE(fit_args$force_refit)
    )
    .assert_vm_fit_result(res, label = paste0(jobs$raw[i], " ", jobs$kappa_struct[i]))
    res
  }

  t0 <- Sys.time()
  n_jobs <- nrow(jobs)
  n_par <- min(plan$n_workers, n_jobs)

  if (n_par <= 1L) {
    results <- lapply(seq_len(n_jobs), run_one)
  } else {
    script_path <- normalizePath("s1_vm_ladder_stan.R", mustWork = TRUE)
    message("Starting PSOCK cluster (", n_par, " workers), script: ", script_path)
    cl <- parallel::makeCluster(n_par)
    on.exit(parallel::stopCluster(cl), add = TRUE)

    parallel::clusterExport(
      cl,
      varlist = c(
        "script_path", "vm_data", "jobs", "level", "kappa_structs", "raw_ids",
        "plan", "chains", "fit_args"
      ),
      envir = environment()
    )
    parallel::clusterEvalQ(cl, {
      suppressPackageStartupMessages({
        library(cmdstanr)
        library(tidyverse)
        library(loo)
        library(posterior)
      })
      source(script_path, local = FALSE)
    })

    results <- parallel::parLapply(cl, seq_len(n_jobs), function(i) {
      vm_stan_fit_job(
        raw = jobs$raw[i],
        kappa_struct = jobs$kappa_struct[i],
        vm_data = vm_data,
        level = level,
        kappa_structs = kappa_structs,
        raw_ids = raw_ids,
        parallel_chains = plan$parallel_chains,
        chains = chains,
        seed = fit_args$seed,
        iter_warmup = fit_args$iter_warmup,
        iter_sampling = fit_args$iter_sampling,
        adapt_delta = fit_args$adapt_delta,
        max_treedepth = fit_args$max_treedepth,
        refresh = fit_args$refresh,
        force_refit = isTRUE(fit_args$force_refit)
      )
    })
    parallel::stopCluster(cl)
    on.exit(NULL, add = FALSE)
  }

  elapsed_min <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
  message("Batch ", level, " finished ", n_jobs, " fits in ", round(elapsed_min, 1), " min")

  fits_by_raw <- list()
  for (i in seq_len(n_jobs)) {
    raw <- jobs$raw[i]
    res <- results[[i]]
    .assert_vm_fit_result(res, label = paste0("Job ", i, " (", raw, " ", jobs$kappa_struct[i], ")"))
    if (is.null(fits_by_raw[[raw]])) fits_by_raw[[raw]] <- list()
    fits_by_raw[[raw]][[res$model_id]] <- res
  }

  compare_by_raw <- list()
  for (raw in raw_ids) {
    fl <- fits_by_raw[[raw]]
    cmp <- map_dfr(fl, function(x) {
      tibble(
        model_id = x$model_id,
        level = x$level,
        kappa_struct = x$kappa_struct,
        elapsed_min = x$elapsed_min,
        elpd_loo = if (!is.null(x$loo)) x$loo$estimates["elpd_loo", "Estimate"] else NA_real_,
        se_loo = if (!is.null(x$loo)) x$loo$estimates["elpd_loo", "SE"] else NA_real_,
        looic = if (!is.null(x$loo)) x$loo$estimates["looic", "Estimate"] else NA_real_,
        waic = if (!is.null(x$waic)) x$waic$estimates["waic", "Estimate"] else NA_real_
      )
    }) %>%
      mutate(
        delta_loo = -elpd_loo + max(elpd_loo, na.rm = TRUE),
        delta_waic = waic - min(waic, na.rm = TRUE)
      ) %>%
      arrange(delta_loo)
    compare_by_raw[[raw]] <- cmp %>% mutate(ID = id_pub[[raw]], raw_ID = raw)
  }

  list(
    fits = fits_by_raw,
    compare = bind_rows(compare_by_raw),
    plan = plan,
    elapsed_min = elapsed_min
  )
}

compare_vm_level_loo <- function(fits) {
  loo_list <- lapply(fits, function(x) x$loo)
  loo_list <- loo_list[!vapply(loo_list, is.null, logical(1))]
  if (length(loo_list) < 2) return(NULL)
  loo_compare(!!!loo_list)
}

# ---- cell-level posterior summaries ----

extract_vm_cell_params_from_draws <- function(fit_obj, dr) {
  prep <- fit_obj$prep
  level <- fit_obj$level
  kappa_struct <- fit_obj$kappa_struct
  dd <- prep$data
  cues <- levels(dd$CueType)
  durs <- levels(dd$DurationF)
  sess <- levels(dd$SessionF)

  log_kappa_base <- vm_param_matrix(dr, "^log_kappa_base\\[")
  log_kappa_sess <- vm_param_matrix(dr, "^log_kappa_sess\\[")

  grid <- expand_grid(
    CueType = factor(cues, levels = cues),
    DurationF = factor(durs, levels = durs),
    SessionF = factor(sess, levels = sess)
  ) %>%
    mutate(
      idx_cue = as.integer(CueType),
      idx_dur = as.integer(DurationF),
      idx_cd = (idx_cue - 1L) * length(durs) + idx_dur,
      idx_sess = as.integer(SessionF),
      kappa_idx = if (kappa_struct == "2k") idx_cue else idx_cd
    )

  kappa_draws <- vm_build_cell_draws(log_kappa_base, grid$kappa_idx, log_kappa_sess, grid$idx_sess)
  kappa_sum <- vm_summarise_draw_mat(kappa_draws, transform = exp)

  out <- grid %>%
    mutate(
      kappa_median = kappa_sum$median,
      kappa_lower = kappa_sum$lower,
      kappa_upper = kappa_sum$upper,
      circSD_deg = circ_sd_from_kappa(kappa_median)
    )

  if (level == "L1") {
    gamma_cd <- vm_param_matrix(dr, "^gamma_cd_logit\\[")
    gamma_sess <- vm_param_matrix(dr, "^gamma_sess_logit\\[")
    gamma_draws <- vm_build_cell_draws(gamma_cd, grid$idx_cd, gamma_sess, grid$idx_sess)
    gamma_sum <- vm_summarise_draw_mat(gamma_draws, transform = plogis)
    out$gamma_median <- gamma_sum$median
    out$gamma_lower <- gamma_sum$lower
    out$gamma_upper <- gamma_sum$upper
  }

  if (level == "L2") {
    beta_cd <- vm_param_matrix(dr, "^beta_cd_logit\\[")
    beta_sess <- vm_param_matrix(dr, "^beta_sess_logit\\[")
    gfrac_cd <- vm_param_matrix(dr, "^gfrac_cd_logit\\[")
    gfrac_sess <- vm_param_matrix(dr, "^gfrac_sess_logit\\[")
    beta_draws <- vm_build_cell_draws(beta_cd, grid$idx_cd, beta_sess, grid$idx_sess)
    gfrac_draws <- vm_build_cell_draws(gfrac_cd, grid$idx_cd, gfrac_sess, grid$idx_sess)
    beta_sum <- vm_summarise_draw_mat(beta_draws, transform = plogis)
    gamma_draws <- (1 - plogis(beta_draws)) * plogis(gfrac_draws)
    gamma_sum <- vm_summarise_draw_mat(gamma_draws, transform = identity)
    out$beta_median <- beta_sum$median
    out$beta_lower <- beta_sum$lower
    out$beta_upper <- beta_sum$upper
    out$gamma_median <- gamma_sum$median
    out$gamma_lower <- gamma_sum$lower
    out$gamma_upper <- gamma_sum$upper
    out$p_target_median <- 1 - out$beta_median - out$gamma_median
  }

  out
}

extract_vm_cell_params <- function(fit_obj) {
  if (!is.null(fit_obj$cell_params) && !isTRUE(getOption("vm_force_reextract", FALSE))) {
    return(fit_obj$cell_params)
  }
  extract_vm_cell_params_from_draws(fit_obj, vm_get_param_draws(fit_obj))
}

colMedians <- function(m) apply(m, 2, median)

# ---- load / collect cached fits ----

vm_fit_cache_path <- function(raw, level, kappa_struct) {
  file.path(
    "bayes_primary_discrete", "vm_stan",
    paste0(raw, "_", level, "_", kappa_struct), "fit_meta.rds"
  )
}

vm_load_fit_cache <- function(raw, level, kappa_struct) {
  path <- vm_fit_cache_path(raw, level, kappa_struct)
  if (!file.exists(path)) {
    return(NULL)
  }
  readRDS(path)
}

vm_collect_all_cell_params <- function(
    raw_ids = c("AQ", "HC", "YILIU", "YDL"),
    id_pub = c(AQ = "P01", HC = "P02", YILIU = "P03", YDL = "P04"),
    levels = c("L0", "L1", "L2"),
    kappa_structs = c("2k", "14k")
) {
  rows <- list()
  for (raw in raw_ids) {
    for (lv in levels) {
      for (ks in kappa_structs) {
        fit <- vm_load_fit_cache(raw, lv, ks)
        if (is.null(fit)) {
          next
        }
        cp <- extract_vm_cell_params(fit)
        rows[[length(rows) + 1L]] <- cp %>%
          mutate(
            ID = id_pub[[raw]],
            raw_ID = raw,
            level = lv,
            kappa_struct = ks,
            model_id = paste0(lv, "_", ks),
            Duration_ms = as.numeric(gsub("ms", "", as.character(DurationF)))
          )
      }
    }
  }
  bind_rows(rows)
}

vm_format_cell_params <- function(cell_df) {
  cell_df %>%
    transmute(
      ID, level, model_id, kappa_struct,
      CueType, Duration_ms, SessionF,
      kappa = kappa_median, kappa_lo = kappa_lower, kappa_hi = kappa_upper,
      circSD_deg,
      gamma = if ("gamma_median" %in% names(.)) gamma_median else NA_real_,
      gamma_lo = if ("gamma_median" %in% names(.)) gamma_lower else NA_real_,
      gamma_hi = if ("gamma_median" %in% names(.)) gamma_upper else NA_real_,
      beta = if ("beta_median" %in% names(.)) beta_median else NA_real_,
      beta_lo = if ("beta_median" %in% names(.)) beta_lower else NA_real_,
      beta_hi = if ("beta_median" %in% names(.)) beta_upper else NA_real_,
      p_target = if ("p_target_median" %in% names(.)) p_target_median else NA_real_
    )
}

# ---- session offset parameters (S2–S10 vs S1 reference) ----

vm_session_offset_table <- function(fit_obj) {
  sm <- fit_obj$summary
  if (is.null(sm) || nrow(sm) == 0) {
    return(tibble())
  }
  sm %>%
    filter(grepl("_(sess|sess_logit)\\[", variable)) %>%
    mutate(
      component = case_when(
        grepl("^log_kappa_sess", variable) ~ "kappa",
        grepl("^gamma_sess_logit", variable) ~ "gamma",
        grepl("^beta_sess_logit", variable) ~ "beta",
        grepl("^gfrac_sess_logit", variable) ~ "gfrac",
        TRUE ~ NA_character_
      ),
      session = as.integer(gsub(".*\\[(\\d+)\\]", "\\1", variable)) + 1L
    ) %>%
    transmute(
      ID = fit_obj$raw_id,
      level = fit_obj$level,
      model_id = fit_obj$model_id,
      component,
      session = factor(session),
      logit_or_log_median = median,
      logit_or_log_lo = q5,
      logit_or_log_hi = q95,
      multiplier_or_logit_add = case_when(
        component == "kappa" ~ exp(median),
        TRUE ~ median
      )
    )
}

vm_collect_session_offsets <- function(
    raw_ids = c("AQ", "HC", "YILIU", "YDL"),
    id_pub = c(AQ = "P01", HC = "P02", YILIU = "P03", YDL = "P04"),
    levels = c("L0", "L1", "L2"),
    kappa_structs = c("2k", "14k")
) {
  rows <- list()
  for (raw in raw_ids) {
    for (lv in levels) {
      for (ks in kappa_structs) {
        fit <- vm_load_fit_cache(raw, lv, ks)
        if (is.null(fit)) {
          next
        }
        off <- vm_session_offset_table(fit)
        if (nrow(off) > 0) {
          off$ID <- id_pub[[raw]]
          off$raw_ID <- raw
          rows[[length(rows) + 1L]] <- off
        }
      }
    }
  }
  bind_rows(rows)
}

vm_session_cell_change <- function(cell_df, param = c("kappa", "gamma", "beta")) {
  param <- match.arg(param)
  med <- paste0(param, "_median")
  lo <- paste0(param, "_lower")
  hi <- paste0(param, "_upper")
  if (!med %in% names(cell_df)) {
    return(tibble())
  }
  wide <- cell_df %>%
    filter(SessionF %in% c("1", "10")) %>%
    mutate(SessionF = factor(SessionF, levels = c("1", "10"))) %>%
    group_by(ID, level, model_id, kappa_struct, CueType, Duration_ms, SessionF) %>%
    summarise(
      est = .data[[med]],
      lo = .data[[lo]],
      hi = .data[[hi]],
      .groups = "drop"
    ) %>%
    pivot_wider(names_from = SessionF, values_from = c(est, lo, hi), names_sep = "_S")
  if (!all(c("est_S1", "est_S10") %in% names(wide))) {
    return(tibble())
  }
  wide %>%
    mutate(
      parameter = param,
      delta_S10_minus_S1 = est_S10 - est_S1,
      delta_lo = est_S10 - hi_S1,
      delta_hi = est_S10 - lo_S1
    ) %>%
    select(ID, level, model_id, kappa_struct, CueType, Duration_ms, parameter,
           S1 = est_S1, S10 = est_S10, delta_S10_minus_S1, delta_lo, delta_hi)
}

# ---- cell-level contrast draws ----

vm_cell_param_draws <- function(fit_obj) {
  dr <- vm_get_param_draws(fit_obj)
  prep <- fit_obj$prep
  level <- fit_obj$level
  kappa_struct <- fit_obj$kappa_struct
  dd <- prep$data
  cues <- levels(dd$CueType)
  durs <- levels(dd$DurationF)
  sess <- levels(dd$SessionF)

  log_kappa_base <- vm_param_matrix(dr, "^log_kappa_base\\[")
  log_kappa_sess <- vm_param_matrix(dr, "^log_kappa_sess\\[")

  grid <- expand_grid(
    CueType = factor(cues, levels = cues),
    DurationF = factor(durs, levels = durs),
    SessionF = factor(sess, levels = sess)
  ) %>%
    mutate(
      idx_cue = as.integer(CueType),
      idx_dur = as.integer(DurationF),
      idx_cd = (idx_cue - 1L) * length(durs) + idx_dur,
      idx_sess = as.integer(SessionF),
      kappa_idx = if (kappa_struct == "2k") idx_cue else idx_cd,
      cell = row_number()
    )

  kappa <- vm_build_cell_draws(log_kappa_base, grid$kappa_idx, log_kappa_sess, grid$idx_sess) %>%
    exp()
  out <- list(kappa = kappa, grid = grid)

  if (level == "L1") {
    gamma_cd <- vm_param_matrix(dr, "^gamma_cd_logit\\[")
    gamma_sess <- vm_param_matrix(dr, "^gamma_sess_logit\\[")
    out$gamma <- plogis(vm_build_cell_draws(gamma_cd, grid$idx_cd, gamma_sess, grid$idx_sess))
  }
  if (level == "L2") {
    beta_cd <- vm_param_matrix(dr, "^beta_cd_logit\\[")
    beta_sess <- vm_param_matrix(dr, "^beta_sess_logit\\[")
    gfrac_cd <- vm_param_matrix(dr, "^gfrac_cd_logit\\[")
    gfrac_sess <- vm_param_matrix(dr, "^gfrac_sess_logit\\[")
    beta_d <- vm_build_cell_draws(beta_cd, grid$idx_cd, beta_sess, grid$idx_sess)
    gfrac_d <- vm_build_cell_draws(gfrac_cd, grid$idx_cd, gfrac_sess, grid$idx_sess)
    out$beta <- plogis(beta_d)
    out$gamma <- (1 - plogis(beta_d)) * plogis(gfrac_d)
    out$p_target <- 1 - out$beta - out$gamma
  }
  out
}

vm_summarise_contrast_draws <- function(draws) {
  tibble(
    median = median(draws),
    lower = unname(quantile(draws, 0.025)),
    upper = unname(quantile(draws, 0.975))
  )
}

vm_cell_index <- function(grid, cue, duration, session = "1") {
  which(
    grid$CueType == cue &
      grid$DurationF == duration &
      grid$SessionF == session
  )
}

vm_theory_contrasts <- function(fit_obj) {
  pd <- vm_cell_param_draws(fit_obj)
  grid <- pd$grid
  id <- fit_obj$raw_id
  lv <- fit_obj$level
  mid <- fit_obj$model_id

  contrast <- function(name, draws) {
    vm_summarise_contrast_draws(draws) %>%
      mutate(
        ID = id, level = lv, model_id = mid, kappa_struct = fit_obj$kappa_struct,
        contrast = name, .before = 1
      )
  }

  rows <- list()
  for (dur in levels(grid$DurationF)) {
    for (sess in c("1", "10")) {
      i_nr <- vm_cell_index(grid, "NR", dur, sess)
      i_r <- vm_cell_index(grid, "R", dur, sess)
      if (length(i_nr) == 0 || length(i_r) == 0) {
        next
      }
      dur_ms <- as.numeric(gsub("ms", "", dur))
      tag <- paste0(dur_ms, "ms_S", sess)
      rows[[length(rows) + 1L]] <- contrast(
        paste0("gain_R_minus_NR_kappa_", tag),
        pd$kappa[, i_r] - pd$kappa[, i_nr]
      )
      if (!is.null(pd$gamma)) {
        rows[[length(rows) + 1L]] <- contrast(
          paste0("gain_R_minus_NR_gamma_", tag),
          pd$gamma[, i_r] - pd$gamma[, i_nr]
        )
      }
      if (!is.null(pd$beta)) {
        rows[[length(rows) + 1L]] <- contrast(
          paste0("gain_R_minus_NR_beta_", tag),
          pd$beta[, i_r] - pd$beta[, i_nr]
        )
      }
    }
  }

  for (cue in c("NR", "R")) {
    for (sess in c("1", "10")) {
      i50 <- vm_cell_index(grid, cue, "50ms", sess)
      i350 <- vm_cell_index(grid, cue, "350ms", sess)
      if (length(i50) == 0 || length(i350) == 0) {
        next
      }
      tag <- paste0(cue, "_S", sess)
      rows[[length(rows) + 1L]] <- contrast(
        paste0("dur350_minus_50_kappa_", tag),
        pd$kappa[, i350] - pd$kappa[, i50]
      )
      if (!is.null(pd$gamma)) {
        rows[[length(rows) + 1L]] <- contrast(
          paste0("dur350_minus_50_gamma_", tag),
          pd$gamma[, i350] - pd$gamma[, i50]
        )
      }
      if (!is.null(pd$beta)) {
        rows[[length(rows) + 1L]] <- contrast(
          paste0("dur350_minus_50_beta_", tag),
          pd$beta[, i350] - pd$beta[, i50]
        )
      }
    }
  }

  for (cue in c("NR", "R")) {
    for (dur in levels(grid$DurationF)) {
      i1 <- vm_cell_index(grid, cue, dur, "1")
      i10 <- vm_cell_index(grid, cue, dur, "10")
      if (length(i1) == 0 || length(i10) == 0) {
        next
      }
      dur_ms <- as.numeric(gsub("ms", "", dur))
      tag <- paste0(cue, "_", dur_ms, "ms")
      rows[[length(rows) + 1L]] <- contrast(
        paste0("session_S10_minus_S1_kappa_", tag),
        pd$kappa[, i10] - pd$kappa[, i1]
      )
      if (!is.null(pd$gamma)) {
        rows[[length(rows) + 1L]] <- contrast(
          paste0("session_S10_minus_S1_gamma_", tag),
          pd$gamma[, i10] - pd$gamma[, i1]
        )
      }
      if (!is.null(pd$beta)) {
        rows[[length(rows) + 1L]] <- contrast(
          paste0("session_S10_minus_S1_beta_", tag),
          pd$beta[, i10] - pd$beta[, i1]
        )
      }
    }
  }

  bind_rows(rows)
}

vm_collect_theory_contrasts <- function(
    raw_ids = c("AQ", "HC", "YILIU", "YDL"),
    id_pub = c(AQ = "P01", HC = "P02", YILIU = "P03", YDL = "P04"),
    levels = c("L1", "L2"),
    kappa_structs = c("2k", "14k")
) {
  rows <- list()
  for (raw in raw_ids) {
    for (lv in levels) {
      for (ks in kappa_structs) {
        fit <- vm_load_fit_cache(raw, lv, ks)
        if (is.null(fit)) {
          next
        }
        tc <- vm_theory_contrasts(fit)
        tc$raw_ID <- raw
        tc$ID <- id_pub[[raw]]
        rows[[length(rows) + 1L]] <- tc
      }
    }
  }
  bind_rows(rows)
}

# ---- posterior predictive density (mixture pdf on grid) ----

log_vm_lpdf <- function(theta, mu, kappa) {
  kappa * cos(theta - mu) - log(2 * pi) -
    log(max(besselI(kappa, 0, expon.scaled = TRUE), .Machine$double.xmin)) - kappa
}

log_sum_exp_rows <- function(x) {
  apply(x, 1, function(r) {
    m <- max(r)
    m + log(sum(exp(r - m)))
  })
}

log_mixture_lpdf <- function(theta, kappa, gamma, beta = 0,
                             mu1 = 0, mu2 = 0, mu3 = 0, level = "L1") {
  if (level == "L0") {
    return(log_vm_lpdf(theta, 0, kappa))
  }
  p_target <- if (level == "L2") max(1 - beta - gamma, 1e-12) else max(1 - gamma, 1e-12)
  log_t <- log(p_target) + log_vm_lpdf(theta, 0, kappa)
  log_g <- rep(log(max(gamma, 1e-12)) - log(2 * pi), length(theta))
  if (level == "L2" && beta > 1e-8) {
    log_s1 <- log(beta / 3) + log_vm_lpdf(theta, mu1, kappa)
    log_s2 <- log(beta / 3) + log_vm_lpdf(theta, mu2, kappa)
    log_s3 <- log(beta / 3) + log_vm_lpdf(theta, mu3, kappa)
    return(log_sum_exp_rows(cbind(log_t, log_s1, log_s2, log_s3, log_g)))
  }
  log_sum_exp_rows(cbind(log_t, log_g))
}

vm_ppc_components_one <- function(theta, kappa, gamma, beta, mu1, mu2, mu3, level,
                                  deg_scale = pi / 180) {
  if (level == "L0") {
    d_vm <- exp(log_vm_lpdf(theta, 0, kappa)) * deg_scale
    return(list(mixture = d_vm))
  }

  p_target <- if (level == "L2") max(1 - beta - gamma, 1e-12) else max(1 - gamma, 1e-12)
  d_target <- p_target * exp(log_vm_lpdf(theta, 0, kappa)) * deg_scale
  d_uniform <- rep(max(gamma, 0) / 360, length(theta))

  if (level == "L2") {
    b <- max(beta, 0)
    if (b > 1e-8) {
      d_s1 <- (b / 3) * exp(log_vm_lpdf(theta, mu1, kappa)) * deg_scale
      d_s2 <- (b / 3) * exp(log_vm_lpdf(theta, mu2, kappa)) * deg_scale
      d_s3 <- (b / 3) * exp(log_vm_lpdf(theta, mu3, kappa)) * deg_scale
    } else {
      d_s1 <- d_s2 <- d_s3 <- rep(0, length(theta))
    }
    d_mix <- d_target + d_s1 + d_s2 + d_s3 + d_uniform
    return(list(
      mixture = d_mix, target = d_target,
      swap1 = d_s1, swap2 = d_s2, swap3 = d_s3, uniform = d_uniform
    ))
  }

  d_mix <- d_target + d_uniform
  list(mixture = d_mix, target = d_target, uniform = d_uniform)
}

vm_ppc_pooled_cell <- function(
    fit_obj,
    cue,
    duration,
    theta_grid_deg = seq(-180, 180, by = 2),
    n_draws = 300
) {
  prep <- fit_obj$prep
  dd <- prep$data
  level <- fit_obj$level
  trials <- dd %>%
    filter(CueType == cue, DurationF == duration)
  if (nrow(trials) == 0) {
    return(NULL)
  }

  sess_df <- trials %>%
    count(SessionF, name = "n") %>%
    mutate(w = n / sum(n))
  sessions <- sess_df$SessionF

  pd <- vm_cell_param_draws(fit_obj)
  dr_n <- nrow(vm_get_param_draws(fit_obj))
  draw_idx <- sample.int(dr_n, min(n_draws, dr_n))
  theta <- theta_grid_deg * pi / 180
  deg_scale <- pi / 180
  n_theta <- length(theta)

  comp_names <- switch(
    level,
    L0 = c("mixture"),
    L1 = c("mixture", "target", "uniform"),
    L2 = c("mixture", "target", "swap1", "swap2", "swap3", "uniform")
  )
  comp_draws <- setNames(
    lapply(comp_names, function(x) matrix(0, nrow = n_theta, ncol = length(draw_idx))),
    comp_names
  )

  for (j in seq_along(draw_idx)) {
    pooled <- setNames(
      lapply(comp_names, function(x) rep(0, n_theta)),
      comp_names
    )
    for (si in seq_len(nrow(sess_df))) {
      sess <- sessions[si]
      w <- sess_df$w[si]
      idx <- vm_cell_index(pd$grid, cue, duration, sess)
      if (length(idx) == 0) {
        next
      }
      k <- pd$kappa[draw_idx[j], idx]
      g <- if (!is.null(pd$gamma)) pd$gamma[draw_idx[j], idx] else 0
      b <- if (!is.null(pd$beta)) pd$beta[draw_idx[j], idx] else 0
      t_idx <- which(
        dd$CueType == cue & dd$DurationF == duration & dd$SessionF == sess
      )[1]
      mu1 <- if (level == "L2") prep$mu1[t_idx] else 0
      mu2 <- if (level == "L2") prep$mu2[t_idx] else 0
      mu3 <- if (level == "L2") prep$mu3[t_idx] else 0
      comps <- vm_ppc_components_one(theta, k, g, b, mu1, mu2, mu3, level, deg_scale)
      for (nm in names(comps)) {
        pooled[[nm]] <- pooled[[nm]] + w * comps[[nm]]
      }
    }
    for (nm in comp_names) {
      comp_draws[[nm]][, j] <- pooled[[nm]]
    }
  }

  summarise_draws <- function(mat) {
    tibble(
      theta_deg = theta_grid_deg,
      density = rowMeans(mat),
      lower = apply(mat, 1, quantile, probs = 0.025),
      upper = apply(mat, 1, quantile, probs = 0.975)
    )
  }

  mixture <- summarise_draws(comp_draws$mixture)
  components <- bind_rows(lapply(setdiff(comp_names, "mixture"), function(nm) {
    summarise_draws(comp_draws[[nm]]) %>%
      mutate(component = nm, .before = 1) %>%
      select(component, theta_deg, density)
  }))

  list(
    mixture = mixture,
    components = components,
    observed = trials$SignedErr,
    meta = tibble(
      ID = fit_obj$raw_id,
      level = fit_obj$level,
      model_id = fit_obj$model_id,
      CueType = cue,
      DurationF = duration,
      n_trials = nrow(trials),
      n_sessions = nrow(sess_df)
    )
  )
}

vm_ppc_compare_levels <- function(
    raw,
    cue,
    duration,
    kappa_struct = "2k",
    levels = c("L0", "L1", "L2"),
    ...
) {
  observed <- NULL
  mixture_rows <- list()
  component_rows <- list()

  for (lv in levels) {
    fit <- vm_load_fit_cache(raw, lv, kappa_struct)
    if (is.null(fit)) {
      next
    }
    pc <- vm_ppc_pooled_cell(fit, cue, duration, ...)
    if (is.null(pc)) {
      next
    }
    observed <- pc$observed
    mixture_rows[[lv]] <- pc$mixture %>%
      mutate(level = lv, .before = 1)
    if (nrow(pc$components) > 0) {
      component_rows[[lv]] <- pc$components %>%
        mutate(level = lv, .before = 1)
    }
  }

  if (is.null(observed)) {
    return(NULL)
  }

  list(
    observed = observed,
    mixture = bind_rows(mixture_rows),
    components = bind_rows(component_rows),
    meta = tibble(
      raw_ID = raw,
      CueType = cue,
      DurationF = duration,
      kappa_struct = kappa_struct,
      n_trials = length(observed)
    )
  )
}

vm_ppc_cell_densities <- function(
    fit_obj,
    cue,
    duration,
    session = "all",
    theta_grid_deg = seq(-180, 180, by = 2),
    n_draws = 400
) {
  if (identical(session, "all")) {
    pc <- vm_ppc_pooled_cell(
      fit_obj, cue, duration,
      theta_grid_deg = theta_grid_deg,
      n_draws = n_draws
    )
    if (is.null(pc)) {
      return(NULL)
    }
    return(list(
      density = pc$mixture,
      observed = pc$observed,
      meta = pc$meta
    ))
  }

  prep <- fit_obj$prep
  dd <- prep$data
  trials <- dd %>%
    filter(CueType == cue, DurationF == duration, SessionF == session)
  if (nrow(trials) == 0) {
    return(NULL)
  }

  pd <- vm_cell_param_draws(fit_obj)
  idx <- vm_cell_index(pd$grid, cue, duration, session)
  dr_n <- nrow(vm_get_param_draws(fit_obj))
  draw_idx <- sample.int(dr_n, min(n_draws, dr_n))

  theta <- theta_grid_deg * pi / 180
  level <- fit_obj$level
  t_idx <- which(
    dd$CueType == cue & dd$DurationF == duration & dd$SessionF == session
  )[1]
  mu1 <- if (level == "L2") prep$mu1[t_idx] else 0
  mu2 <- if (level == "L2") prep$mu2[t_idx] else 0
  mu3 <- if (level == "L2") prep$mu3[t_idx] else 0

  dens <- matrix(0, nrow = length(theta), ncol = length(draw_idx))
  for (j in seq_along(draw_idx)) {
    k <- pd$kappa[draw_idx[j], idx]
    g <- if (!is.null(pd$gamma)) pd$gamma[draw_idx[j], idx] else 0
    b <- if (!is.null(pd$beta)) pd$beta[draw_idx[j], idx] else 0
    dens[, j] <- exp(log_mixture_lpdf(
      theta, k, g, b, mu1, mu2, mu3, level = level
    ))
  }

  dens_mean <- rowMeans(dens)
  dens_q025 <- apply(dens, 1, quantile, probs = 0.025)
  dens_q975 <- apply(dens, 1, quantile, probs = 0.975)
  deg_scale <- pi / 180

  list(
    density = tibble(
      theta_deg = theta_grid_deg,
      density = dens_mean * deg_scale,
      lower = dens_q025 * deg_scale,
      upper = dens_q975 * deg_scale
    ),
    observed = trials$SignedErr,
    meta = tibble(
      ID = fit_obj$raw_id,
      level = fit_obj$level,
      model_id = fit_obj$model_id,
      CueType = cue,
      DurationF = duration,
      SessionF = session,
      n_trials = nrow(trials)
    )
  )
}

# ---- participant data list helper ----

vm_participant_data <- function(d) {
  id_raw <- c("AQ", "HC", "YILIU", "YDL")
  id_pub <- c("P01", "P02", "P03", "P04")
  names(id_pub) <- id_raw
  out <- list()
  for (raw in id_raw) {
    out[[raw]] <- d %>%
      filter(ID == id_pub[[raw]]) %>%
      droplevels()
  }
  out
}
