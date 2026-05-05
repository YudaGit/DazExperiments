source("trial_gen.R")
source("sim_runner.R")

# Editable model parameters for this run.
beta <- list(
  baseAlpha = 10.0,
  baseKappa = 20.0,
  vnorm = 5.0,
  eta1 = 0.5,
  eta2 = 0.001,
  a = 5.0,
  ter = 0.0,
  st = 0.00
)

design <- list(
  itemN = 1:4,
  mode = c("baseline", "R_R", "R_NR", "homoR"),
  preDur = 0.4,
  retDur = 0.8,
  min_sep = 30,
  even_positions = TRUE,
  redundantN = 1:4
)

x <- gen_trial_table(design, reps_per_cell = 500, seed = 42)

sim <- sim_from_table(
  x$trial_table,
  beta = beta,
  pop_tune = "alpha",
  sim_mode = "error_only",
  smooth_gt = TRUE,
  smooth_theta_bw = 1,
  smooth_time_bw = 1,
  reuse_dist = TRUE
)

plot_all_cond_pairs(sim, out_file = "sim_cond_pairs.pdf")

