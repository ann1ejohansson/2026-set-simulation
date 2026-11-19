# View SET results for one condition
# choose a condition (and student) below, then compare the SET settings
# (window_size x weights x beta) within it:
#  1. p(dominant cause) over the sequence, per setting
#  2. recovery: share of windows where the top cause is the dominant cause
#  3. prediction: share of windows where the top cause is the next error's true cause
# needs the output of 03-run-set.R for the run set in cfg.R

source("scripts/cfg.R")

# choose ----
# pick by settings, or set condition_id (overrides the settings)
sel_n_errors <- 100
sel_p_dom <- 0
sel_dom_cause <- NA # NA for the baseline (p_dom = 0)
sel_noise_prob <- 0.3
condition_id <- NULL

student <- 1 # used for plot 1; plots 2 and 3 average over all students

save_figs <- FALSE # TRUE saves the plots to figures/<run>/

# load ----

set_dir <- file.path(cfg$results_dir, "set")
conditions <- read_rds(file.path(cfg$data_dir, "conditions.rds"))

cond <- if (!is.null(condition_id)) {
  filter(conditions, .data$condition_id == .env$condition_id)
} else {
  filter(
    conditions,
    n_errors == sel_n_errors,
    near(p_dom, sel_p_dom),
    (is.na(dom_cause) & is.na(sel_dom_cause)) | dom_cause %in% sel_dom_cause,
    near(noise_prob, sel_noise_prob)
  )
}
if (nrow(cond) != 1) {
  stop(
    "Selection matches ",
    nrow(cond),
    " conditions; it must match exactly 1. ",
    "See conditions.csv in ",
    cfg$data_dir,
    " for the options."
  )
}

res_file <- file.path(set_dir, cond$file)
if (!file.exists(res_file)) {
  stop(
    "No SET results for ",
    cond$file,
    ". Either 03-run-set.R has not been run, ",
    "or the condition was skipped (n_errors smaller than every window size)."
  )
}
res <- read_rds(res_file)
if (nrow(res) == 0) {
  stop(
    "SET gave no output for this condition: every student had fewer explained errors than the smallest window."
  )
}

dom <- cond$dom_cause
has_dom <- !is.na(dom)
cond_label <- sprintf(
  "condition %d: n_errors = %d, p_dom = %.1f, dominant cause = %s, noise = %.2f",
  cond$condition_id,
  cond$n_errors,
  cond$p_dom,
  replace_na(dom, "none"),
  cond$noise_prob
)
message(cond_label)

# per window: recovery and next-error prediction
res <- res %>%
  mutate(
    p_dom_cause = if (has_dom) .data[[paste0("p_", dom)]] else NA_real_,
    recovered = top_cause == dom,
    has_next = !is.na(next_true_cause),
    next_hit = if_else(has_next, top_cause == next_true_cause, NA),
    next_plausible = if_else(
      has_next,
      map2_lgl(top_cause, next_causes, `%in%`),
      NA
    ),
    weights = factor(weights, levels = cfg$weight_method),
    beta = factor(beta)
  )

# summary per setting ----

summary_settings <- res %>%
  group_by(window_size, weights, beta) %>%
  summarise(
    n_windows = n(),
    recovery = mean(recovered),
    mean_p_dom = mean(p_dom_cause),
    next_hit = mean(next_hit, na.rm = TRUE),
    next_plausible = mean(next_plausible, na.rm = TRUE),
    .groups = "drop"
  )
print(summary_settings, n = Inf)

# which cause SET puts on top, per setting (useful for the baseline)
top_causes <- res %>%
  count(window_size, weights, beta, top_cause) %>%
  group_by(window_size, weights, beta) %>%
  mutate(share = n / sum(n)) %>%
  slice_max(share, n = 1, with_ties = FALSE) %>%
  ungroup()
print(top_causes, n = Inf)

# plots ----

# beta is ordered: one-hue ramp, light to dark
beta_cols <- c("#86b6ef", "#3987e5", "#1c5cab", "#0d366b")
beta_cols <- setNames(beta_cols[seq_along(levels(res$beta))], levels(res$beta))

theme_set_view <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
    strip.text = element_text(face = "bold", colour = "grey20"),
    plot.title = element_text(face = "bold"),
    plot.subtitle = element_text(colour = "grey35"),
    legend.position = "top"
  )

plots <- list()

## 1. p(dominant cause) over the sequence ----
if (has_dom) {
  res_student <- filter(res, student_id == student)
  plots$sequence <- ggplot(
    res_student,
    aes(window_end, p_dom_cause, colour = beta, group = beta)
  ) +
    geom_line(linewidth = 0.5) +
    facet_grid(
      window_size ~ weights,
      labeller = labeller(window_size = \(x) paste("window", x))
    ) +
    scale_colour_manual(values = beta_cols) +
    scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1)) +
    labs(
      title = sprintf(
        "SET's probability of the dominant cause (%s), student %d",
        dom,
        student
      ),
      subtitle = cond_label,
      x = "Last error in the window (position in the full sequence)",
      y = sprintf("p(%s)", dom),
      colour = "beta"
    ) +
    theme_set_view
}

## 2. and 3. heatmaps per setting ----
heatmap_settings <- function(var, title) {
  ggplot(summary_settings, aes(beta, weights, fill = .data[[var]])) +
    geom_tile(colour = "white", linewidth = 1) +
    geom_text(
      aes(
        label = scales::percent(.data[[var]], accuracy = 1),
        colour = .data[[var]] > 0.6
      ),
      size = 3.2
    ) +
    facet_wrap(~window_size, nrow = 1, labeller = \(x) {
      label_both(x, sep = " ")
    }) +
    scale_fill_gradient(
      low = "#cde2fb",
      high = "#0d366b",
      limits = c(0, 1),
      labels = scales::percent
    ) +
    scale_colour_manual(
      values = c(`FALSE` = "grey15", `TRUE` = "white"),
      guide = "none"
    ) +
    labs(
      title = title,
      subtitle = cond_label,
      x = "beta",
      y = NULL,
      fill = NULL
    ) +
    theme_set_view +
    theme(panel.grid = element_blank(), legend.key.width = unit(2, "cm"))
}

if (has_dom) {
  plots$recovery <- heatmap_settings(
    "recovery",
    "Recovery: share of windows where SET's top cause is the dominant cause"
  )
}
plots$prediction <- heatmap_settings(
  "next_hit",
  "Prediction: share of windows where SET's top cause is the next error's true cause"
)

walk(plots, print)

if (save_figs) {
  fig_dir <- file.path("figures", run)
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  iwalk(plots, \(p, name) {
    ggsave(
      file.path(fig_dir, sprintf("c%03d_%s.png", cond$condition_id, name)),
      p,
      width = 11,
      height = if (name == "sequence") 9 else 4,
      dpi = 150,
      bg = "white"
    )
  })
}
