suppressPackageStartupMessages({
  library(tidyverse)
  library(brms)
  library(tidybayes)
  library(emmeans)
})

setwd("/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/Encoding 2025-26/Encoding Small-N/AnalysesR")
set.seed(1234)
options(mc.cores = 4)

d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE) %>%
  mutate(
    ID = factor(ID),
    CueType = factor(CueType, levels = c("NR", "R")),
    DurationF = factor(Duration, levels = c(
      "50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms"
    )),
    SessionF = factor(Session)
  )

d_AQ <- droplevels(filter(d, ID == "AQ"))

rope_abs <- 3
early_z <- mean(unique(d$Session_z[d$Session %in% c(1, 2)]))
late_z <- mean(unique(d$Session_z[d$Session %in% c(9, 10)]))
session_slices <- c(early = early_z, average = 0, late = late_z)
linear_duration_weights <- c(-3, -2, -1, 0, 1, 2, 3)

bayes_priors <- c(
  prior(normal(30, 20), class = Intercept),
  prior(normal(0, 15), class = b),
  prior(exponential(1), class = sigma),
  prior(exponential(1), class = sd),
  prior(gamma(2, 0.1), class = nu)
)

message("SMOKE FIT AQ: 2 chains x 600 iter")
m <- brm(
  AbsErr ~ CueType * DurationF * Session_z + (1 | SessionF),
  data = d_AQ,
  family = student(),
  prior = bayes_priors,
  chains = 2,
  cores = 2,
  iter = 600,
  warmup = 300,
  control = list(adapt_delta = 0.9),
  seed = 1234,
  file = "bayes_primary/m_AQ_abserr_smoke",
  file_refit = "on_change"
)

summarise_effect <- function(data, effect_name) {
  tibble(
    effect = effect_name,
    median = median(data$.value),
    mean = mean(data$.value),
    lower = as.numeric(quantile(data$.value, 0.025)),
    upper = as.numeric(quantile(data$.value, 0.975)),
    p_lt_0 = mean(data$.value < 0),
    p_gt_0 = mean(data$.value > 0),
    p_in_rope = mean(abs(data$.value) < rope_abs)
  )
}

contrast_draws <- function(model, emm_formula, at_list, contrast_list, by = NULL) {
  emm <- emmeans(model, specs = emm_formula, at = at_list)
  ct <- contrast(emm, method = contrast_list, by = by)
  gather_emmeans_draws(ct)
}

# Duration by cue
duration_by_cue <- contrast_draws(
  m, ~ DurationF | CueType, list(Session_z = 0),
  list(
    "linear_trend" = linear_duration_weights,
    "350ms - 50ms" = c(-1, 0, 0, 0, 0, 0, 1)
  ),
  by = "CueType"
)

duration_summary <- duration_by_cue %>%
  group_by(CueType, contrast) %>%
  group_modify(~ summarise_effect(.x, unique(.y$contrast))) %>%
  ungroup() %>%
  mutate(effect = paste(CueType, contrast, sep = ": "))

catch_avg <- duration_by_cue %>%
  filter(contrast == "350ms - 50ms") %>%
  select(.draw, CueType, .value) %>%
  pivot_wider(names_from = CueType, values_from = .value) %>%
  mutate(.value = R - NR) %>%
  summarise_effect("catchup_average")

# Catch-up by session
duration_by_cue_session <- contrast_draws(
  m, ~ DurationF | CueType * Session_z,
  list(Session_z = unname(session_slices)),
  list("350ms - 50ms" = c(-1, 0, 0, 0, 0, 0, 1)),
  by = c("CueType", "Session_z")
) %>%
  mutate(
    SessionSlice = case_when(
      abs(Session_z - early_z) < 1e-8 ~ "early",
      abs(Session_z - 0) < 1e-8 ~ "average",
      abs(Session_z - late_z) < 1e-8 ~ "late"
    )
  )

catch_by_session <- duration_by_cue_session %>%
  select(.draw, CueType, SessionSlice, .value) %>%
  pivot_wider(names_from = CueType, values_from = .value) %>%
  mutate(.value = R - NR) %>%
  group_by(SessionSlice) %>%
  group_modify(~ summarise_effect(.x, unique(.y$SessionSlice))) %>%
  ungroup()

gain_50 <- contrast_draws(
  m, ~ CueType | DurationF, list(Session_z = 0),
  list("NR - R" = c(1, -1)), by = "DurationF"
) %>%
  filter(DurationF == "50ms") %>%
  summarise_effect("gain_at_50ms")

cat("\n=== SMOKE CONTRASTS OK ===\n")
print(bind_rows(gain_50, duration_summary, catch_avg, catch_by_session))
cat("\nN draws check:", length(unique(duration_by_cue$.draw)), "\n")
cat("CueType cols present:", all(c("NR", "R") %in% names(
  duration_by_cue %>%
    filter(contrast == "350ms - 50ms") %>%
    select(.draw, CueType, .value) %>%
    pivot_wider(names_from = CueType, values_from = .value)
)), "\n")
