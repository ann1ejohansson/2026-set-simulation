# 03. RUN SET
# runs SET on every student's error sequence from 01-generate-errors.R, for all
# window_size x weight_method x beta settings in cfg (see run_set_student()).
# every student, window, and setting has one output row, window and setting:
#  - recovery: top_cause / p_<cause> against the student's dom_cause
#  - prediction: the same probabilities against the next explained error
#    (next_true_cause, next_causes)
# conditions where every window size is larger than n_errors are skipped.

source("scripts/cfg.R")

# in the code-testing run, start from an empty results folder
if (run == "code-testing" && dir.exists(cfg$results_dir)) {
  unlink(cfg$results_dir, recursive = TRUE)
}

conditions <- read_rds(file.path(cfg$data_dir, "conditions.rds"))

# ties in SET's probabilities are broken by theoretical base rate
tie_order <- read_rds(file.path(cfg$data_dir, "base_rate_theoretical.rds")) %>%
  arrange(desc(base_rate)) %>%
  pull(name)

set_dir <- file.path(cfg$results_dir, "set")
dir.create(set_dir, recursive = TRUE, showWarnings = FALSE)

run_conditions <- conditions %>%
  filter(n_errors >= min(cfg$window_size))

message(sprintf(
  "Running SET on %d of %d conditions (%d skipped: n_errors < smallest window), %d settings each",
  nrow(run_conditions),
  nrow(conditions),
  nrow(conditions) - nrow(run_conditions),
  length(cfg$weight_method) * length(cfg$beta)
))

# run ----

start_time <- Sys.time()

for (k in seq_len(nrow(run_conditions))) {
  cond <- run_conditions[k, ]
  errors <- read_rds(file.path(cfg$data_dir, cond$file))

  set_out <- errors %>%
    group_by(student_id, dom_cause) %>%
    group_modify(\(x, key) {
      run_set_student(x, tie_order = tie_order) %||% tibble()
    }) %>%
    ungroup() %>%
    mutate(
      condition_id = cond$condition_id,
      n_errors = cond$n_errors,
      p_dom = cond$p_dom,
      noise_prob = cond$noise_prob,
      .before = 1
    )

  write_rds(set_out, file.path(set_dir, cond$file))

  if (
    k %% max(1, round(nrow(run_conditions) / 10)) == 0 ||
      k == nrow(run_conditions)
  ) {
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
    message(sprintf(
      "%d/%d conditions | %.1f min elapsed | ~%.1f min left",
      k,
      nrow(run_conditions),
      elapsed,
      elapsed / k * (nrow(run_conditions) - k)
    ))
  }
}

write_rds(run_conditions, file.path(set_dir, "set_conditions.rds"))
