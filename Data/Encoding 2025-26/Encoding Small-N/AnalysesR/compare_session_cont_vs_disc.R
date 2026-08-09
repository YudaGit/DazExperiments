# Compare AbsErr Bayes: continuous Session_z vs discrete SessionF
# Runs discrete fits if needed, recomputes theory_focus for both, writes comparison.

suppressPackageStartupMessages({
  library(tidyverse)
  library(brms)
  library(emmeans)
  library(tidybayes)
})

setwd("/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/Encoding 2025-26/Encoding Small-N/AnalysesR")
set.seed(1234)
options(mc.cores = parallel::detectCores())

rope_abs <- 3
w_linear <- c(-3, -2, -1, 0, 1, 2, 3)
w_350_minus_50 <- c(-1, 0, 0, 0, 0, 0, 1)

d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE) %>%
  mutate(
    ID = factor(ID),
    CueType = factor(CueType, levels = c("NR", "R")),
    DurationF = factor(
      Duration,
      levels = c("50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms")
    ),
    SessionF = factor(Session)
  )

d_AQ <- droplevels(filter(d, ID == "AQ"))
d_HC <- droplevels(filter(d, ID == "HC"))
d_YILIU <- droplevels(filter(d, ID == "YILIU"))

sess_levels <- levels(d$SessionF)
early_sessions <- c("1", "2")
late_sessions <- c("9", "10")
early_z <- mean(unique(d$Session_z[d$Session %in% c(1, 2)]))
late_z <- mean(unique(d$Session_z[d$Session %in% c(9, 10)]))

priors_cont <- c(
  prior(normal(30, 20), class = "Intercept"),
  prior(normal(0, 15), class = "b"),
  prior(exponential(1), class = "sigma"),
  prior(exponential(1), class = "sd"),
  prior(gamma(2, 0.1), class = "nu")
)
priors_disc <- c(
  prior(normal(30, 20), class = "Intercept"),
  prior(normal(0, 15), class = "b"),
  prior(exponential(1), class = "sigma"),
  prior(gamma(2, 0.1), class = "nu")
)

dir.create("bayes_primary", showWarnings = FALSE, recursive = TRUE)
dir.create("bayes_primary_discrete", showWarnings = FALSE, recursive = TRUE)

message("Loading / fitting continuous Session_z models ...")
m_cont <- list(
  AQ = brm(
    AbsErr ~ CueType * DurationF * Session_z + (1 | SessionF),
    data = d_AQ, family = student(), prior = priors_cont,
    chains = 4, cores = 4, iter = 4000, warmup = 2000,
    control = list(adapt_delta = 0.95, max_treedepth = 12), seed = 1234,
    file = "bayes_primary/m_AQ_abserr", file_refit = "on_change"
  ),
  HC = brm(
    AbsErr ~ CueType * DurationF * Session_z + (1 | SessionF),
    data = d_HC, family = student(), prior = priors_cont,
    chains = 4, cores = 4, iter = 4000, warmup = 2000,
    control = list(adapt_delta = 0.95, max_treedepth = 12), seed = 1234,
    file = "bayes_primary/m_HC_abserr", file_refit = "on_change"
  ),
  YILIU = brm(
    AbsErr ~ CueType * DurationF * Session_z + (1 | SessionF),
    data = d_YILIU, family = student(), prior = priors_cont,
    chains = 4, cores = 4, iter = 4000, warmup = 2000,
    control = list(adapt_delta = 0.95, max_treedepth = 12), seed = 1234,
    file = "bayes_primary/m_YILIU_abserr", file_refit = "on_change"
  )
)

message("Loading / fitting discrete SessionF models ...")
m_disc <- list(
  AQ = brm(
    AbsErr ~ CueType * DurationF * SessionF,
    data = d_AQ, family = student(), prior = priors_disc,
    chains = 4, cores = 4, iter = 4000, warmup = 2000,
    control = list(adapt_delta = 0.95, max_treedepth = 12), seed = 1234,
    file = "bayes_primary_discrete/m_AQ_abserr", file_refit = "on_change"
  ),
  HC = brm(
    AbsErr ~ CueType * DurationF * SessionF,
    data = d_HC, family = student(), prior = priors_disc,
    chains = 4, cores = 4, iter = 4000, warmup = 2000,
    control = list(adapt_delta = 0.95, max_treedepth = 12), seed = 1234,
    file = "bayes_primary_discrete/m_HC_abserr", file_refit = "on_change"
  ),
  YILIU = brm(
    AbsErr ~ CueType * DurationF * SessionF,
    data = d_YILIU, family = student(), prior = priors_disc,
    chains = 4, cores = 4, iter = 4000, warmup = 2000,
    control = list(adapt_delta = 0.95, max_treedepth = 12), seed = 1234,
    file = "bayes_primary_discrete/m_YILIU_abserr", file_refit = "on_change"
  )
)

summarise_v <- function(v, pid, effect) {
  v <- v[is.finite(v)]
  tibble(
    ID = pid, effect = effect,
    median = median(v),
    lower = as.numeric(quantile(v, 0.025)),
    upper = as.numeric(quantile(v, 0.975)),
    p_lt_0 = mean(v < 0),
    p_gt_0 = mean(v > 0),
    p_in_rope = mean(abs(v) < rope_abs)
  )
}

theory_effects <- c(
  "gain_at_50ms",
  "NR: linear_trend", "R: linear_trend",
  "NR: 350ms - 50ms", "R: 350ms - 50ms",
  "catchup_early", "catchup_average", "catchup_late",
  "catchup_late_minus_early",
  "NR: duration_effect_late_minus_early",
  "R: duration_effect_late_minus_early"
)

# ---- continuous contrasts ----
message("Contrasts: continuous ...")
rows_c <- list()
for (pid in names(m_cont)) {
  model <- m_cont[[pid]]
  emm_gain <- emmeans(model, ~ CueType | DurationF, at = list(Session_z = 0))
  dg <- gather_emmeans_draws(contrast(emm_gain, method = list("NR - R" = c(1, -1)), by = "DurationF"))
  rows_c[[length(rows_c) + 1]] <- summarise_v(dg$.value[dg$DurationF == "50ms"], pid, "gain_at_50ms")

  emm_dur <- emmeans(model, ~ DurationF | CueType, at = list(Session_z = 0))
  dd <- gather_emmeans_draws(contrast(
    emm_dur,
    method = list("linear_trend" = w_linear, "350ms - 50ms" = w_350_minus_50),
    by = "CueType"
  ))
  for (cue in c("NR", "R")) {
    for (cn in c("linear_trend", "350ms - 50ms")) {
      rows_c[[length(rows_c) + 1]] <- summarise_v(
        dd$.value[dd$CueType == cue & dd$contrast == cn], pid, paste0(cue, ": ", cn)
      )
    }
  }

  emm_ds <- emmeans(
    model, ~ DurationF | CueType * Session_z,
    at = list(Session_z = c(early_z, 0, late_z))
  )
  ds <- gather_emmeans_draws(contrast(
    emm_ds, method = list("350ms - 50ms" = w_350_minus_50),
    by = c("CueType", "Session_z")
  ))
  sz <- sort(unique(ds$Session_z))
  ds$SessionSlice <- c("early", "average", "late")[match(ds$Session_z, sz)]

  for (slice in c("early", "average", "late")) {
    wide <- ds %>% filter(SessionSlice == slice) %>%
      select(.draw, CueType, .value) %>%
      pivot_wider(names_from = CueType, values_from = .value)
    rows_c[[length(rows_c) + 1]] <- summarise_v(wide$R - wide$NR, pid, paste0("catchup_", slice))
  }
  we <- ds %>% filter(SessionSlice == "early") %>%
    select(.draw, CueType, .value) %>% pivot_wider(names_from = CueType, values_from = .value) %>%
    mutate(catchup = R - NR)
  wl <- ds %>% filter(SessionSlice == "late") %>%
    select(.draw, CueType, .value) %>% pivot_wider(names_from = CueType, values_from = .value) %>%
    mutate(catchup = R - NR)
  rows_c[[length(rows_c) + 1]] <- summarise_v(
    wl$catchup[match(we$.draw, wl$.draw)] - we$catchup, pid, "catchup_late_minus_early"
  )
  for (cue in c("NR", "R")) {
    wc <- ds %>% filter(CueType == cue, SessionSlice %in% c("early", "late")) %>%
      select(.draw, SessionSlice, .value) %>%
      pivot_wider(names_from = SessionSlice, values_from = .value)
    rows_c[[length(rows_c) + 1]] <- summarise_v(
      wc$late - wc$early, pid, paste0(cue, ": duration_effect_late_minus_early")
    )
  }
}
cont_tf <- bind_rows(rows_c) %>% filter(effect %in% theory_effects)

# ---- discrete contrasts ----
message("Contrasts: discrete ...")
rows_d <- list()
for (pid in names(m_disc)) {
  model <- m_disc[[pid]]
  emm_gain <- emmeans(model, ~ CueType | DurationF)
  dg <- gather_emmeans_draws(contrast(emm_gain, method = list("NR - R" = c(1, -1)), by = "DurationF"))
  rows_d[[length(rows_d) + 1]] <- summarise_v(dg$.value[dg$DurationF == "50ms"], pid, "gain_at_50ms")

  emm_dur <- emmeans(model, ~ DurationF | CueType)
  dd <- gather_emmeans_draws(contrast(
    emm_dur,
    method = list("linear_trend" = w_linear, "350ms - 50ms" = w_350_minus_50),
    by = "CueType"
  ))
  for (cue in c("NR", "R")) {
    for (cn in c("linear_trend", "350ms - 50ms")) {
      rows_d[[length(rows_d) + 1]] <- summarise_v(
        dd$.value[dd$CueType == cue & dd$contrast == cn], pid, paste0(cue, ": ", cn)
      )
    }
  }

  emm_ds <- emmeans(model, ~ DurationF | CueType * SessionF)
  ds <- gather_emmeans_draws(contrast(
    emm_ds, method = list("350ms - 50ms" = w_350_minus_50),
    by = c("CueType", "SessionF")
  ))
  ds$SessionF <- as.character(ds$SessionF)
  slice_early <- ds %>% filter(SessionF %in% early_sessions) %>%
    group_by(.draw, CueType) %>% summarise(.value = mean(.value), .groups = "drop")
  slice_average <- ds %>% filter(SessionF %in% sess_levels) %>%
    group_by(.draw, CueType) %>% summarise(.value = mean(.value), .groups = "drop")
  slice_late <- ds %>% filter(SessionF %in% late_sessions) %>%
    group_by(.draw, CueType) %>% summarise(.value = mean(.value), .groups = "drop")

  for (slice_name in c("early", "average", "late")) {
    sl <- list(early = slice_early, average = slice_average, late = slice_late)[[slice_name]]
    wide <- sl %>% pivot_wider(names_from = CueType, values_from = .value)
    rows_d[[length(rows_d) + 1]] <- summarise_v(wide$R - wide$NR, pid, paste0("catchup_", slice_name))
  }
  we <- slice_early %>% pivot_wider(names_from = CueType, values_from = .value) %>% mutate(catchup = R - NR)
  wl <- slice_late %>% pivot_wider(names_from = CueType, values_from = .value) %>% mutate(catchup = R - NR)
  rows_d[[length(rows_d) + 1]] <- summarise_v(
    wl$catchup[match(we$.draw, wl$.draw)] - we$catchup, pid, "catchup_late_minus_early"
  )
  for (cue in c("NR", "R")) {
    e <- slice_early %>% filter(CueType == cue) %>% arrange(.draw)
    l <- slice_late %>% filter(CueType == cue) %>% arrange(.draw)
    rows_d[[length(rows_d) + 1]] <- summarise_v(
      l$.value - e$.value, pid, paste0(cue, ": duration_effect_late_minus_early")
    )
  }
}
disc_tf <- bind_rows(rows_d) %>% filter(effect %in% theory_effects)

cmp <- cont_tf %>%
  select(ID, effect, median, lower, upper, p_lt_0, p_gt_0, p_in_rope) %>%
  rename_with(~ paste0("cont_", .x), -c(ID, effect)) %>%
  left_join(
    disc_tf %>%
      select(ID, effect, median, lower, upper, p_lt_0, p_gt_0, p_in_rope) %>%
      rename_with(~ paste0("disc_", .x), -c(ID, effect)),
    by = c("ID", "effect")
  ) %>%
  mutate(
    median_diff = disc_median - cont_median,
    # Direction agreement: both favor <0, both >0, or both in ROPE-dominant story via sign of median
    same_sign = sign(cont_median) == sign(disc_median),
    both_exclude_0 = (cont_lower > 0 & disc_lower > 0) | (cont_upper < 0 & disc_upper < 0) |
      (cont_lower < 0 & cont_upper > 0 & disc_lower < 0 & disc_upper > 0),
    # Practical: |median diff| and whether CrI-overlap-with-0 status matches
    cont_excludes_0 = cont_lower > 0 | cont_upper < 0,
    disc_excludes_0 = disc_lower > 0 | disc_upper < 0,
    same_exclude_0 = cont_excludes_0 == disc_excludes_0
  ) %>%
  arrange(effect, ID)

write_csv(cont_tf, "bayes_primary_discrete/theory_focus_continuous_ref.csv")
write_csv(disc_tf, "bayes_primary_discrete/theory_focus.csv")
write_csv(cmp, "bayes_primary_discrete/compare_cont_vs_disc.csv")

message("\n=== Comparison: continuous Session_z vs discrete SessionF ===\n")
print(
  cmp %>%
    transmute(
      ID, effect,
      cont = round(cont_median, 2),
      disc = round(disc_median, 2),
      diff = round(median_diff, 2),
      same_sign,
      same_exclude_0
    ),
  n = 100
)

message("\nSummary:")
message("  same median sign: ", mean(cmp$same_sign), " (", sum(cmp$same_sign), "/", nrow(cmp), ")")
message("  same excludes-0:  ", mean(cmp$same_exclude_0), " (", sum(cmp$same_exclude_0), "/", nrow(cmp), ")")
message("  |median diff| median: ", round(median(abs(cmp$median_diff)), 2), " deg")
message("  |median diff| max:    ", round(max(abs(cmp$median_diff)), 2), " deg")

# Highlight rows where conclusions differ on excluding 0
differs <- cmp %>% filter(!same_exclude_0 | !same_sign)
message("\nRows with sign or excludes-0 disagreement:")
print(
  differs %>%
    transmute(ID, effect,
              cont_med = round(cont_median, 2), disc_med = round(disc_median, 2),
              same_sign, same_exclude_0),
  n = 50
)

message("Done.")
