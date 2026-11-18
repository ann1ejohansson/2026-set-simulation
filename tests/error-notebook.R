# Error Notebook: interactive view of the generated error sequences
# Run from the 2026-set-simulation folder, after 01-generate-errors.R.
# Builds tests/error-notebook/<run>.html from the run set in cfg.R and opens it
# in the browser. Pick a condition and student, and replay the sequence error by
# error with each error's true cause and every cause that fits its response.
# To build it for another folder, set check_dir before sourcing,
# e.g. check_dir <- "data/some-other-run"

source("scripts/cfg.R")
run_dir <- if (exists("check_dir")) check_dir else cfg$data_dir
run_name <- basename(run_dir)

conditions <- read_rds(file.path(run_dir, "conditions.rds"))
cause_probs <- read_rds(file.path(run_dir, "cause_probs.rds"))
cause_responses <- read_rds(file.path(run_dir, "cause_responses.rds"))
expected_shares <- read_rds(file.path(run_dir, "expected_shares.rds"))

# which causes could have produced each (item, response) pair, keyed "m,n,response"
fits <- cause_responses %>%
  select(m, n, cause, responses) %>%
  unnest(responses) %>%
  mutate(key = paste(m, n, responses, sep = ",")) %>%
  group_by(key) %>%
  summarise(causes = list(cause))

# one entry per condition; each student is a list of [m, n, correct, response, true_cause]
notebook_conditions <- map(seq_len(nrow(conditions)), \(k) {
  cond <- conditions[k, ]
  errors <- read_rds(file.path(run_dir, cond$file))
  list(
    id = cond$condition_id,
    seed = cond$seed,
    n = cond$n_errors,
    pdom = cond$p_dom,
    dom = cond$dom_cause,
    noise = cond$noise_prob,
    # expected share of each true cause under the generating script's model
    exp = expected_shares %>%
      filter(condition_id == cond$condition_id) %>%
      { setNames(as.list(.$expected), .$cause) },
    students = errors %>%
      split(.$student_id) %>%
      map(\(s) pmap(list(s$m, s$n, s$correct, s$response, s$true_cause), list)) %>%
      unname()
  )
})

notebook_data <- list(
  run = run_name,
  probs = setNames(as.list(cause_probs$prob), cause_probs$cause),
  fits = setNames(fits$causes, fits$key),
  conditions = notebook_conditions
)

# fill the data into the page template
template <- read_file("tests/error-notebook/template.html")
json <- jsonlite::toJSON(notebook_data, auto_unbox = TRUE, na = "null", digits = 6)
page <- sub("/*DATA*/null", json, template, fixed = TRUE)
# declare UTF-8 so the browser shows ×, − and other symbols correctly
page <- paste0(
  '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n',
  '<meta name="viewport" content="width=device-width, initial-scale=1">\n',
  "</head>\n<body>\n",
  page,
  "\n</body>\n</html>\n"
)

out_file <- file.path("tests", "error-notebook", paste0(run_name, ".html"))
write_file(page, out_file)
message("Error Notebook written to ", out_file)

if (interactive()) browseURL(normalizePath(out_file))
