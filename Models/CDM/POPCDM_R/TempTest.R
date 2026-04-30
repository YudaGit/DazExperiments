source("trial_gen.R")
source("sim_runner.R")
source("vis_sim.R")

design <- list(
  itemN = 1:4,
  mode = c("baseline", "R_R", "R_NR", "homoR"),
  preDur = c(0.4),
  retDur = 0.8,
  min_sep = 30,
  even_positions = TRUE,
  redundantN = 1
)

x <- gen_trial_table(design, reps_per_cell = 100, seed = 42)
sim <- sim_from_table(x$trial_table)

sum_tab <- summarize_sim(sim)
head(sum_tab)

# pick one condition to visualize
plot_cond_pair(sim, cond = unique(cond_key(sim))[1])
