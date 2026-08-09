suppressPackageStartupMessages({
  library(tidyverse)
  library(brms)
  library(tidybayes)
  library(emmeans)
})

setwd("/Users/prefabteam_ysl/Documents/GitHub/DazExperiments/Data/Encoding 2025-26/Encoding Small-N/AnalysesR")
set.seed(1234)
options(mc.cores = 4)

dir.create("bayes_primary", showWarnings = FALSE, recursive = TRUE)

d <- read_csv("S1_smallN_model_ready.csv", show_col_types = FALSE) %>%
  mutate(
    ID = factor(ID),
    CueType = factor(CueType, levels = c("NR", "R")),
    DurationF = factor(Duration, levels = c(
      "50ms", "100ms", "150ms", "200ms", "250ms", "300ms", "350ms"
    )),
    SessionF = factor(Session)
  )

participants <- c("AQ", "HC", "YILIU")
datasets <- setNames(
  lapply(participants, function(pid) droplevels(filter(d, ID == pid))),
  participants
)

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

participant_primary_contrasts <- function(model, participant) {
  gain_draws <- contrast_draws(
    model, ~ CueType | DurationF, list(Session_z = 0),
    list("NR - R" = c(1, -1)), by = "DurationF"
  ) %>% mutate(ID = participant)

  gain_50 <- gain_draws %>%
    filter(DurationF == "50ms") %>%
    summarise_effect("gain_at_50ms") %>%
    mutate(ID = participant)

  duration_by_cue <- contrast_draws(
    model, ~ DurationF | CueType, list(Session_z = 0),
    list(
      "linear_trend" = linear_duration_weights,
      "350ms - 50ms" = c(-1, 0, 0, 0, 0, 0, 1)
    ),
    by = "CueType"
  ) %>% mutate(ID = participant)

  duration_summary <- duration_by_cue %>%
    group_by(CueType, contrast) %>%
    group_modify(~ summarise_effect(.x, unique(.y$contrast))) %>%
    ungroup() %>%
    mutate(ID = participant, effect = paste(CueType, contrast, sep = ": "))

  catch_avg <- duration_by_cue %>%
    filter(contrast == "350ms - 50ms") %>%
    select(.draw, CueType, .value) %>%
    pivot_wider(names_from = CueType, values_from = .value) %>%
    mutate(.value = R - NR) %>%
    summarise_effect("catchup_average") %>%
    mutate(ID = participant)

  duration_by_cue_session <- contrast_draws(
    model, ~ DurationF | CueType * Session_z,
    list(Session_z = unname(session_slices)),
    list("350ms - 50ms" = c(-1, 0, 0, 0, 0, 0, 1)),
    by = c("CueType", "Session_z")
  ) %>%
    mutate(
      ID = participant,
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
    ungroup() %>%
    mutate(ID = participant, effect = paste0("catchup_", SessionSlice))

  catch_progression <- duration_by_cue_session %>%
    select(.draw, CueType, SessionSlice, .value) %>%
    pivot_wider(names_from = CueType, values_from = .value) %>%
    mutate(catchup = R - NR) %>%
    select(.draw, SessionSlice, catchup) %>%
    pivot_wider(names_from = SessionSlice, values_from = catchup) %>%
    mutate(.value = late - early) %>%
    summarise_effect("catchup_late_minus_early") %>%
    mutate(ID = participant)

  practice_by_cue <- duration_by_cue_session %>%
    filter(SessionSlice %in% c("early", "late")) %>%
    select(.draw, CueType, SessionSlice, .value) %>%
    pivot_wider(names_from = SessionSlice, values_from = .value) %>%
    mutate(.value = late - early) %>%
    group_by(CueType) %>%
    group_modify(~ summarise_effect(.x, as.character(unique(.y$CueType)))) %>%
    ungroup() %>%
    mutate(
      ID = participant,
      effect = paste0(CueType, ": duration_effect_late_minus_early")
    )

  list(
    gain_50 = gain_50,
    duration_summary = duration_summary,
    catch_avg = catch_avg,
    catch_by_session = catch_by_session,
    catch_progression = catch_progression,
    practice_by_cue = practice_by_cue
  )
}

models <- list()
for (pid in participants) {
  message("==== Fitting ", pid, " ====")
  models[[pid]] <- brm(
    AbsErr ~ CueType * DurationF * Session_z + (1 | SessionF),
    data = datasets[[pid]],
    family = student(),
    prior = bayes_priors,
    chains = 4,
    cores = 4,
    iter = 4000,
    warmup = 2000,
    control = list(adapt_delta = 0.95, max_treedepth = 12),
    seed = 1234,
    file = file.path("bayes_primary", paste0("m_", pid, "_abserr")),
    file_refit = "on_change"
  )
  print(summary(models[[pid]]))
}

message("==== Computing contrasts ====")
contrasts <- lapply(participants, function(pid) {
  participant_primary_contrasts(models[[pid]], pid)
})
names(contrasts) <- participants

primary_summary <- bind_rows(
  lapply(contrasts, `[[`, "gain_50"),
  lapply(contrasts, `[[`, "duration_summary"),
  lapply(contrasts, `[[`, "catch_avg"),
  lapply(contrasts, `[[`, "catch_by_session"),
  lapply(contrasts, `[[`, "catch_progression"),
  lapply(contrasts, `[[`, "practice_by_cue")
) %>%
  select(ID, effect, median, lower, upper, p_lt_0, p_gt_0, p_in_rope) %>%
  arrange(effect, ID)

write_csv(primary_summary, "bayes_primary/primary_summary.csv")
saveRDS(contrasts, "bayes_primary/primary_contrasts.rds")

theory_focus <- primary_summary %>%
  filter(
    effect %in% c(
      "gain_at_50ms",
      "NR: linear_trend", "R: linear_trend",
      "NR: 350ms - 50ms", "R: 350ms - 50ms",
      "catchup_early", "catchup_average", "catchup_late",
      "catchup_late_minus_early",
      "NR: duration_effect_late_minus_early",
      "R: duration_effect_late_minus_early"
    )
  )
write_csv(theory_focus, "bayes_primary/theory_focus.csv")

cat("\n===== PRIMARY SUMMARY =====\n")
print(as.data.frame(primary_summary), digits = 3)
cat("\nDONE\n")
