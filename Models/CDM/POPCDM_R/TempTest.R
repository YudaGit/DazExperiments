rm(list = ls())

src <- "C:/Users/Yuda/Documents/GitHub/DazExperiments/Models/CDM/POPCDM_R/trial_gen.R"
file.exists(src)
source(src)

# confirm loaded function includes redundantN in expand.grid
make_conditions

design <- list(
  itemN = 1:6,
  mode = c("baseline", "R_R", "R_NR", "homoR"),
  preDur = c(0.2),
  retDur = 0.8,
  min_sep = 30,
  even_positions = TRUE,
  redundantN = 1:6
)

cond <- make_conditions(design)
cond[, c("itemN","mode","redundantN","preDur","retDur")]
