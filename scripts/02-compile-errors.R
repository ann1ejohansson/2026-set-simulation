# 02. COMPILE ERROR SEQUENCES
# combine the per-condition files from 01-generate-errors.R into one data set,
# keeping only the conditions selected below.
# files are found through conditions.rds, so files left over from earlier runs
# in the same folder are never picked up.

source("scripts/cfg.R")

# selection ----
# name of the compiled file (saved to data/<run>/compiled/<name>.rds)
compiled_name <- "all"

conditions <- read_rds(file.path(cfg$data_dir, "conditions.rds"))

# keep the conditions you want; delete or comment out a line to keep all levels.
# dom_cause is NA for the baseline conditions (p_dom = 0): use
# is.na(dom_cause) | dom_cause %in% c(...) to keep them when filtering on it
selected <- conditions %>%
  filter(
    n_errors %in% cfg$n_errors,
    p_dom %in% cfg$p_dom,
    is.na(dom_cause) | dom_cause %in% cfg$dom_causes,
    noise_prob %in% cfg$noise_prob
  )

# compile ----

paths <- file.path(cfg$data_dir, selected$file)
missing <- paths[!file.exists(paths)]
if (length(missing) > 0) {
  stop(
    length(missing),
    " selected condition file(s) not found, e.g. ",
    basename(missing[1]),
    ". Re-run 01-generate-errors.R."
  )
}

compiled <- map_dfr(paths, read_rds)

out_dir <- file.path(cfg$data_dir, "compiled")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_file <- file.path(out_dir, paste0(compiled_name, ".rds"))
write_rds(compiled, out_file)

message(sprintf(
  "Compiled %d of %d conditions: %s rows, %s students -> %s (%s)",
  nrow(selected),
  nrow(conditions),
  format(nrow(compiled), big.mark = ","),
  format(nrow(distinct(compiled, condition_id, student_id)), big.mark = ","),
  out_file,
  format(structure(file.size(out_file), class = "object_size"), units = "auto")
))
