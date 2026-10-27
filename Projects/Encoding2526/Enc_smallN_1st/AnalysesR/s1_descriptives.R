# First laboratory study: validated descriptive summaries and figures.
# Run with Rscript s1_descriptives.R from this directory or the project root.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_dirs <- if (length(script_arg)) dirname(sub("^--file=", "", script_arg)) else character()
source_dirs <- vapply(sys.frames(), function(frame) {
  if (is.null(frame$ofile)) NA_character_ else dirname(frame$ofile)
}, character(1))
candidates <- unique(c(
  script_dirs, source_dirs, getwd(), file.path(getwd(), "AnalysesR"),
  file.path(getwd(), "Enc_smallN_1st", "AnalysesR")
))
candidates <- candidates[!is.na(candidates)]
candidates <- candidates[file.exists(file.path(candidates, "S1_smallN_model_ready.csv"))]
if (!length(candidates)) stop("Cannot locate first-study model-ready CSV")
analysis_dir <- normalizePath(candidates[1], mustWork = TRUE)
output_dir <- file.path(analysis_dir, "descriptives")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

d <- read_csv(file.path(analysis_dir, "S1_smallN_model_ready.csv"), show_col_types = FALSE)
required <- c("ID", "Session", "CueType", "Duration_ms", "SignedErr", "AbsErr",
              "RT", "TargetIdx", "TargetHue", "ResponseHue")
if (!all(required %in% names(d))) stop("Model-ready CSV is missing required columns")
if (anyNA(d[, required])) stop("Model-ready CSV contains missing required values")
ids <- c("AQ", "HC", "YILIU", "YDL")
durations <- seq(50, 350, 50)
if (!setequal(unique(d$ID), ids) ||
    !setequal(unique(d$Session), 1:10) ||
    !setequal(unique(d$CueType), c("NR", "R")) ||
    !setequal(unique(d$Duration_ms), durations)) {
  stop("Participants, sessions, cues, or durations differ from the planned design")
}
if (any(d$RT < 300 | d$RT > 3000)) stop("RT outside the advance exclusion window")
if (any(d$AbsErr < 0 | abs(d$AbsErr - abs(d$SignedErr)) > 1e-8)) {
  stop("Absolute and signed errors disagree")
}
wrap_deg <- function(x) ((x + 180) %% 360) - 180
if (any(abs(wrap_deg(d$TargetHue - d$ResponseHue) - d$SignedErr) > 1e-6)) {
  stop("Signed error does not match target minus response hue")
}
item_cols <- paste0("ItemHue", 1:6)
if (!all(item_cols %in% names(d))) stop("Model-ready CSV lacks item hues")
item_hues <- as.matrix(d[, item_cols])
target_hues <- item_hues[cbind(seq_len(nrow(d)), d$TargetIdx)]
if (any(abs(target_hues - d$TargetHue) > 1e-8)) {
  stop("Target index and target hue disagree")
}

planned_sessions <- d %>% count(ID, Session, name = "n")
if (nrow(planned_sessions) != 40L || any(planned_sessions$n < 419L) ||
    any(planned_sessions$n > 420L)) stop("Unexpected participant-session trial count")
cell_n <- d %>% count(ID, CueType, Duration_ms, name = "n")
if (nrow(cell_n) != 56L || any(cell_n$n < 299L) || any(cell_n$n > 300L)) {
  stop("Unexpected participant-cue-duration trial count")
}

# Circular SD uses the mean resultant length of signed angles. Intervals are
# descriptive percentile bootstraps over trials within each pooled cell.
cir_sd <- function(x) {
  resultant <- Mod(mean(exp(1i * x * pi / 180)))
  sqrt(-2 * log(max(resultant, .Machine$double.xmin))) * 180 / pi
}
ci_boot <- function(x, statistic, B = 2000L) {
  draws <- replicate(B, statistic(sample(x, length(x), replace = TRUE)))
  unname(quantile(draws, c(0.025, 0.975)))
}

set.seed(1234)
cells <- d %>%
  group_by(ID, CueType, Duration_ms) %>%
  group_modify(function(x, key) {
    ci_cir <- ci_boot(x$SignedErr, cir_sd)
    ci_rt <- ci_boot(x$RT, median)
    tibble(
      n = nrow(x),
      cirSD = cir_sd(x$SignedErr), cirSD_low95 = ci_cir[1],
      cirSD_high95 = ci_cir[2], mean_AbsErr = mean(x$AbsErr),
      fraction_within_15deg = mean(x$AbsErr <= 15),
      fraction_over_90deg = mean(x$AbsErr > 90),
      median_RT = median(x$RT), median_RT_low95 = ci_rt[1],
      median_RT_high95 = ci_rt[2], mean_RT = mean(x$RT)
    )
  }) %>%
  ungroup() %>%
  arrange(factor(ID, levels = ids), CueType, Duration_ms)

session_cells <- d %>%
  group_by(ID, Session, CueType, Duration_ms) %>%
  summarise(
    n = n(), cirSD = cir_sd(SignedErr), mean_AbsErr = mean(AbsErr),
    fraction_within_15deg = mean(AbsErr <= 15),
    fraction_over_90deg = mean(AbsErr > 90),
    median_RT = median(RT), mean_RT = mean(RT), .groups = "drop"
  ) %>%
  arrange(factor(ID, levels = ids), Session, CueType, Duration_ms)

# Each session condition has approximately 30 trials. Bootstrap its circular
# SD and median RT separately so the ten-panel figures show uncertainty at
# the same aggregation level as their points.
set.seed(4321)
session_intervals <- d %>%
  group_by(ID, Session, CueType, Duration_ms) %>%
  group_modify(function(x, key) {
    cir <- ci_boot(x$SignedErr, cir_sd)
    rt <- ci_boot(x$RT, median)
    tibble(cirSD_low95 = cir[1], cirSD_high95 = cir[2],
           median_RT_low95 = rt[1], median_RT_high95 = rt[2])
  }) %>%
  ungroup()
session_cells <- session_cells %>%
  left_join(session_intervals,
            by = c("ID", "Session", "CueType", "Duration_ms"))

endpoints <- cells %>%
  filter(Duration_ms %in% c(50, 350)) %>%
  select(ID, CueType, Duration_ms, cirSD, median_RT) %>%
  tidyr::pivot_wider(names_from = Duration_ms, values_from = c(cirSD, median_RT)) %>%
  mutate(cirSD_350_minus_50 = cirSD_350 - cirSD_50,
         median_RT_350_minus_50 = median_RT_350 - median_RT_50)

write_csv(planned_sessions, file.path(output_dir, "session_counts.csv"))
write_csv(cells, file.path(output_dir, "cue_duration_summary.csv"))
write_csv(session_cells, file.path(output_dir, "session_cue_duration_summary.csv"))
write_csv(endpoints, file.path(output_dir, "duration_endpoints.csv"))

# Raw absolute errors and circular SD share degrees but are different
# quantities. The figure labels them explicitly; raw errors underlay the
# pooled circular-SD summary rather than being called individual cirSDs.
display_id <- c(YDL = "YDL", YILIU = "YIL", HC = "HC", AQ = "AQ")
display_levels <- unname(display_id)
label_id <- function(x) factor(unname(display_id[as.character(x)]),
                               levels = display_levels)
cells$Participant <- label_id(cells$ID)
session_cells$Participant <- label_id(session_cells$ID)
cells$CueType <- factor(cells$CueType, levels = c("NR", "R"))
session_cells$CueType <- factor(session_cells$CueType, levels = c("NR", "R"))
trial_plot <- d %>%
  mutate(Participant = label_id(ID),
         CueType = factor(CueType, levels = c("NR", "R")))

# Small offsets keep R/NR raw trials and summaries distinct at each duration.
offset <- c(NR = -6, R = 6)
cells$x_plot <- cells$Duration_ms + unname(offset[as.character(cells$CueType)])
session_cells$x_plot <- session_cells$Duration_ms +
  unname(offset[as.character(session_cells$CueType)])
trial_plot$x_plot <- trial_plot$Duration_ms +
  unname(offset[as.character(trial_plot$CueType)])

palette <- c(NR = "#0072B2", R = "#D55E00")
condition_labels <- c(NR = "Nonredundant", R = "Redundant")
# The generic serif family is portable across raster and vector devices.
figure_font <- "serif"
figure_theme <- theme_classic(base_size = 9, base_family = figure_font) +
  theme(
    panel.grid.major.y = element_line(colour = "grey90", linewidth = 0.22),
    axis.line = element_line(linewidth = 0.3),
    axis.ticks = element_line(linewidth = 0.3),
    strip.background = element_blank(),
    strip.text = element_text(face = "bold", size = 10),
    panel.spacing = grid::unit(8, "mm"),
    legend.position = "bottom",
    legend.key.width = grid::unit(13, "mm"),
    plot.caption = element_text(size = 7, hjust = 0, margin = margin(t = 3, unit = "mm")),
    plot.margin = margin(4, 5, 4, 4, unit = "mm")
  )
figure_scales <- list(
  scale_x_continuous(breaks = c(50, 150, 250, 350),
                     limits = c(32, 368), expand = expansion(mult = 0)),
  scale_colour_manual(values = palette, labels = condition_labels, name = "Condition"),
  scale_shape_manual(values = c(NR = 16, R = 17),
                     labels = condition_labels, name = "Condition")
)

plot_summary <- function(summary_y, low, high, raw_y, y_label, caption) {
  ggplot() + raw_layer(raw_y) +
    geom_errorbar(
      data = cells,
      aes(x = x_plot, ymin = .data[[low]], ymax = .data[[high]],
          colour = CueType), width = 3.8, linewidth = 0.36,
      show.legend = FALSE
    ) +
    geom_point(
      data = cells,
      aes(x = x_plot, y = .data[[summary_y]], colour = CueType,
          shape = CueType), size = 2, stroke = 0.5
    ) +
    facet_wrap(~Participant, ncol = 2) +
    figure_scales + figure_theme +
    labs(x = "Encoding duration (ms)", y = y_label, caption = caption)
}

raw_layer <- function(value_col) {
  geom_point(
    data = trial_plot,
    aes(x = x_plot, y = .data[[value_col]], colour = CueType),
    position = position_jitter(width = 3, height = 0, seed = 1234),
    alpha = 0.09, size = 0.38, stroke = 0, show.legend = FALSE
  )
}

p_cir <- plot_summary(
  "cirSD", "cirSD_low95", "cirSD_high95", "AbsErr",
  "Absolute error / circular SD (°)",
  "Faint points: raw absolute errors. Large symbols and bars: pooled circular SD and 95% bootstrap CI."
) +
  scale_y_continuous(breaks = c(0, 45, 90, 135, 180), limits = c(0, 180),
                     expand = expansion(mult = 0))
p_rt <- plot_summary(
  "median_RT", "median_RT_low95", "median_RT_high95", "RT",
  "Response time (ms)",
  "Faint points: raw response times. Large symbols and bars: pooled median and 95% bootstrap CI."
)

# Each first/last-session condition has about 30 trials. Intervals resample
# trials within that session × cue × duration cell; the same y scale is used
# across all eight panels for a direct visual comparison.
set.seed(1234)
first_last <- d %>%
  filter(Session %in% c(1, 10)) %>%
  group_by(ID, Session, CueType, Duration_ms) %>%
  group_modify(function(x, key) {
    interval <- ci_boot(x$SignedErr, cir_sd)
    tibble(n = nrow(x), cirSD = cir_sd(x$SignedErr),
           cirSD_low95 = interval[1], cirSD_high95 = interval[2])
  }) %>%
  ungroup() %>%
  mutate(
    Participant = label_id(ID),
    Session_label = factor(if_else(Session == 1, "First session", "Last session"),
                           levels = c("First session", "Last session")),
    CueType = factor(CueType, levels = c("NR", "R")),
    x_plot = Duration_ms + unname(offset[as.character(CueType)])
  )
write_csv(first_last %>% mutate(Participant = as.character(Participant),
                               Session_label = as.character(Session_label)),
          file.path(output_dir, "first_last_session_cirsd.csv"))

p_first_last <- ggplot(first_last,
                       aes(x = x_plot, y = cirSD, colour = CueType,
                           shape = CueType,
                           group = CueType)) +
  geom_errorbar(aes(ymin = cirSD_low95, ymax = cirSD_high95),
                width = 3.8, linewidth = 0.33, show.legend = FALSE) +
  geom_point(size = 1.65) +
  facet_grid(Participant ~ Session_label, switch = "y") +
  figure_scales + figure_theme +
  theme(strip.placement = "outside", panel.spacing.y = grid::unit(5, "mm")) +
  labs(x = "Encoding duration (ms)", y = "Circular SD (°)")

# Longitudinal descriptive view: seven durations and both cues in every
# session. A single y range is used for all ten panels of each participant.
# The range follows the session-summary intervals; raw-trial tails outside
# that range are clipped only for display and their fraction is reported.
session_dir <- file.path(output_dir, "session_panels")
dir.create(session_dir, showWarnings = FALSE, recursive = TRUE)
session_levels <- paste("Session", 1:10)
session_cells$Session_label <- factor(paste("Session", session_cells$Session),
                                      levels = session_levels)
trial_plot$Session_label <- factor(paste("Session", trial_plot$Session),
                                   levels = session_levels)

session_panel_plot <- function(raw_id, outcome = c("cirSD", "RT")) {
  outcome <- match.arg(outcome)
  summary <- session_cells %>% filter(ID == raw_id)
  raw <- trial_plot %>% filter(ID == raw_id)
  if (outcome == "cirSD") {
    estimate <- "cirSD"; low <- "cirSD_low95"; high <- "cirSD_high95"
    raw_value <- "AbsErr"; axis_label <- "Absolute error / circular SD (°)"
    upper <- ceiling(max(summary[[high]]) / 10) * 10
    limits <- c(0, upper)
    note <- "Raw points: absolute errors; large symbols: session circular SD with 95% bootstrap CI."
  } else {
    estimate <- "median_RT"; low <- "median_RT_low95"
    high <- "median_RT_high95"; raw_value <- "RT"
    axis_label <- "Response time (ms)"
    span <- max(summary[[high]]) - min(summary[[low]])
    limits <- c(floor((min(summary[[low]]) - 0.06 * span) / 50) * 50,
                ceiling((max(summary[[high]]) + 0.06 * span) / 50) * 50)
    note <- "Raw points: trial RT; large symbols: session median with 95% bootstrap CI."
  }
  clipped <- mean(raw[[raw_value]] < limits[1] | raw[[raw_value]] > limits[2])
  caption <- paste(
    note,
    sprintf("Fixed y-axis across sessions; %.1f%% of raw trials lie outside this zoom.",
            100 * clipped),
    sep = "\n"
  )
  plot <- ggplot() +
    # Repeat the lower reference line in every facet, rather than only on
    # the bottom (Session 10) axis drawn by ggplot2.
    geom_hline(yintercept = limits[1], colour = "black", linewidth = 0.3) +
    geom_point(
      data = raw,
      aes(x = x_plot, y = .data[[raw_value]], colour = CueType),
      position = position_jitter(width = 2.2, height = 0, seed = 1234),
      alpha = 0.17, size = 0.42, stroke = 0, show.legend = FALSE
    ) +
    geom_errorbar(
      data = summary,
      aes(x = x_plot, ymin = .data[[low]], ymax = .data[[high]],
          colour = CueType), width = 4, linewidth = 0.32,
      show.legend = FALSE
    ) +
    geom_point(
      data = summary,
      aes(x = x_plot, y = .data[[estimate]], colour = CueType,
          shape = CueType), size = 1.7, stroke = 0.4
    ) +
    facet_grid(Session_label ~ ., switch = "y") +
    figure_scales + figure_theme +
    scale_y_continuous(breaks = pretty(limits, n = 3)) +
    coord_cartesian(ylim = limits) +
    theme(
      panel.spacing.y = grid::unit(1.2, "mm"),
      strip.placement = "outside",
      strip.text.y.left = element_text(angle = 0, hjust = 1, size = 8),
      axis.line.x = element_blank(),
      axis.text.y = element_text(size = 7),
      plot.title = element_text(face = "bold", size = 11, hjust = 0.5),
      plot.caption = element_text(size = 7, hjust = 0)
    ) +
    labs(title = display_id[[raw_id]], x = "Encoding duration (ms)",
         y = axis_label, caption = caption)
  list(plot = plot, limits = limits, clipped_fraction = clipped)
}

session_figure_manifest <- list()
for (raw_id in names(display_id)) {
  for (outcome in c("cirSD", "RT")) {
    result <- session_panel_plot(raw_id, outcome)
    stem <- paste0(display_id[[raw_id]], "_",
                   if (outcome == "cirSD") "circular_sd" else "median_rt",
                   "_by_session")
    ggsave(file.path(session_dir, paste0(stem, ".png")), result$plot,
           width = 180, height = 315, units = "mm", dpi = 600, bg = "white")
    session_figure_manifest[[length(session_figure_manifest) + 1L]] <-
      tibble(ID = raw_id, DisplayID = display_id[[raw_id]],
             measure = outcome, y_min = result$limits[1],
             y_max = result$limits[2],
             raw_fraction_clipped = result$clipped_fraction,
             file = paste0(stem, ".png"))
  }
}
write_csv(bind_rows(session_figure_manifest),
          file.path(session_dir, "figure_manifest.csv"))

save_figure <- function(plot, stem, width_mm, height_mm) {
  # Re-enable vector PDF export if needed for manuscript submission.
  # ggsave(file.path(output_dir, paste0(stem, ".pdf")), plot,
  #        width = width_mm, height = height_mm, units = "mm",
  #        device = function(filename, ...) grDevices::pdf(filename, ...,
  #                                                         useDingbats = FALSE),
  #        bg = "white")
  ggsave(file.path(output_dir, paste0(stem, ".png")), plot,
         width = width_mm, height = height_mm, units = "mm", dpi = 600,
         bg = "white")
}
save_figure(p_cir, "circular_sd_by_cue_duration", 180, 145)
save_figure(p_rt, "median_rt_by_cue_duration", 180, 145)
save_figure(p_first_last, "circular_sd_first_vs_last_session", 180, 225)

cat("Validated", nrow(d), "cleaned trials across", nrow(planned_sessions),
    "sessions and", nrow(cells), "cue-duration cells.\n")
cat("Descriptive outputs:", output_dir, "\n")
