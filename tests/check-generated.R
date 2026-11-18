# Checks on the generated error sequences (output of 01-generate-errors.R)
# Run from the 2026-set-simulation folder, after 01-generate-errors.R.
# Works per condition file; nothing is combined into one big data frame.

# run to check is set by `run` in cfg.R. To check another folder, set check_dir
# before sourcing, e.g. check_dir <- "data/some-other-run"
source("scripts/cfg.R")
run_dir <- if (exists("check_dir")) check_dir else cfg$data_dir

conditions <- read_rds(file.path(run_dir, "conditions.rds"))
cause_probs <- read_rds(file.path(run_dir, "cause_probs.rds"))
cause_responses <- read_rds(file.path(run_dir, "cause_responses.rds"))
# expected share of each true cause per condition, written by the generating script
expected_shares <- read_rds(file.path(run_dir, "expected_shares.rds"))

read_condition <- function(id) {
  read_rds(file.path(run_dir, conditions$file[conditions$condition_id == id]))
}

# which causes could have produced each (item, response) pair
plausible_causes <- cause_responses %>%
  select(m, n, cause, responses) %>%
  unnest(responses) %>%
  rename(response = responses, plausible = cause)

# 1. Look at one condition by hand --------------------------------------------

print(read_condition(1), n = 20)

# 2. Basic validity, per condition ---------------------------------------------
# right number of rows, no correct answers, and every response is one that its
# true cause can produce on that item (noise errors excepted)

validity <- map_dfr(conditions$condition_id, \(id) {
  errors <- read_condition(id)
  cond <- filter(conditions, condition_id == id)

  fits_true_cause <- errors %>%
    filter(true_cause != "noise") %>%
    semi_join(plausible_causes, by = c("m", "n", "response", "true_cause" = "plausible"))

  tibble(
    condition_id = id,
    n_rows_ok = nrow(errors) == cond$n_errors * n_distinct(errors$student_id),
    no_correct = all(errors$response != errors$correct),
    all_fit_true_cause = nrow(fits_true_cause) == sum(errors$true_cause != "noise"),
    dom_cause_ok = all(errors$dom_cause %in% cond$dom_cause)
  )
})

validity %>% filter(!if_all(-condition_id))  # empty if everything is fine

# 3. Realised cause shares in the baseline vs. expected shares ----------------
# (expected shares differ from cause_probs, because a cause can only be drawn
# on items where it can produce an error)

baseline_ids <- conditions %>%
  filter(p_dom == 0, noise_prob == 0) %>%
  pull(condition_id)

baseline_ids %>%
  map_dfr(\(id) count(read_condition(id), cause = true_cause)) %>%
  count(cause, wt = n) %>%
  mutate(share = n / sum(n)) %>%
  right_join(
    expected_shares %>%
      filter(condition_id == first(baseline_ids)) %>%
      select(cause, expected),
    by = "cause"
  ) %>%
  left_join(cause_probs, by = "cause") %>%
  replace_na(list(n = 0, share = 0)) %>%
  arrange(desc(expected))

# 4. Per student: generated responses vs. the student's cause profile ----------

check_students <- function(id) {
  read_condition(id) %>%
    mutate(error_id = row_number()) %>%
    left_join(
      plausible_causes,
      by = c("m", "n", "response"),
      relationship = "many-to-many"
    ) %>%
    group_by(
      error_id,
      condition_id,
      student_id,
      n_errors,
      p_dom,
      noise_prob,
      dom_cause,
      true_cause
    ) %>%
    summarise(
      dom_fits = any(plausible == dom_cause, na.rm = TRUE),
      n_fits = sum(!is.na(plausible)),
      .groups = "drop"
    ) %>%
    left_join(expected_shares, by = c("condition_id", "dom_cause" = "cause")) %>%
    group_by(condition_id, student_id, n_errors, p_dom, noise_prob, dom_cause) %>%
    summarise(
      expected_dom = first(expected),
      true_dom = mean(true_cause == dom_cause), # share actually caused by it
      fits_dom = mean(dom_fits), # share whose response fits it
      only_dom = mean(dom_fits & n_fits == 1), # share that fits only it
      n_noise = sum(true_cause == "noise"),
      mean_fits = mean(n_fits), # ambiguity per error
      .groups = "drop"
    )
}

student_check <- map_dfr(conditions$condition_id, check_students)

student_check %>% filter(p_dom > 0) %>% print(n = Inf)
